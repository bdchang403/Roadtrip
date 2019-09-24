import React from 'react';
import axios from 'axios';
import Geosuggest from 'react-geosuggest';
import Grid from '@material-ui/core/Grid';
import Button from '@material-ui/core/Button';
import ButtonGroup from '@material-ui/core/ButtonGroup';
import { GOOGLE_API_KEY } from '../constants/roadtrip_api.js';
const google = window.google;
let PlacesAPICallCounter = 0;

// Location component captures users' route and attractions
class Location extends React.Component {
    constructor(props){
        super(props);
        this.state = {
            origin: undefined,
            destination: undefined,
            attractions: undefined,
            scanThroughRoute: false,
            callsCompletedbyPlacesAPI: 0,
            route: [],
            places: [],
        }
    }

    // Function for handling submission of state change and invoke fetchRoute function
    handleSubmit = (eventType, event) => {
        event.preventDefault()
        // Reset route, places and indicators before fulfilling submit and clear calls
        PlacesAPICallCounter = 0;
        this.setState({
            route: [],
            places: [],
            callsCompletedbyPlacesAPI: 0,
            scanThroughRoute: false     
        })
        // Fetch route upon submission
        if (eventType === "Submit") {
            this.fetchRoute();
            localStorage.setItem("attractions", this.state.attractions);
        }
        // Clear localstorage and reload page
        if (eventType === "Clear") {
            localStorage.clear()
            setTimeout(() => {
                window.location.reload();
            }, 250);
        }
    }

    // Function for handling non-geosuggest variable changes
    handleChange = (event) => {
        this.setState({
          [event.target.name]: event.target.value
        })
      }

    // Function for handling suggestions for geosuggest
    onSuggestion = (suggestionType, suggest) => {
        try {
            this.setState({ [suggestionType]: `${suggest.location.lat},${suggest.location.lng}` });
            localStorage.setItem([suggestionType], suggest.description);
        } catch (error) {
            this.setState({
                [suggestionType]: ""
            });
        }
    }
    
    // The function fetchRoute will call the Google Maps Directions API to get the route details of the road trip
    fetchRoute = async () => {  
        const proxyAddress = "https://cors-anywhere.herokuapp.com/"
        const googleDirection = "https://maps.googleapis.com/maps/api/directions/json?"
        const start = this.state.origin
        const end = this.state.destination
        const key = GOOGLE_API_KEY
        try {
            const routeData = await axios.get(`${proxyAddress}${googleDirection}origin=${start}&destination=${end}&key=${key}`,{
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'X-Content-Type-Options': 'nosniff',
                    'x-requested-with': 'XMLHttpRequest',
                }
            })
            this.setState({
                route: routeData.data.routes[0].legs[0].steps
            })
        } catch(error){
            console.log(error.message);
            alert("Incorrect Origin or Destination. Please try again");
        }
    }

    // The function fetchPlaces will call the Google Maps Places API to get attractions near a set of lat and longitudes
    fetchPlaces = async (location, radius) => {  
        if(this.state.route.length !== 0){
            const proxyAddress = "https://cors-anywhere.herokuapp.com/"
            const googlePlaces = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
            const place = (this.state.attractions).replace(" ", "%20")
            const key = GOOGLE_API_KEY
            let input = `location=${location}&radius=${radius}&keyword=${place}`  
            try {
                const placeData = await axios.get(`${proxyAddress}${googlePlaces}${input}&key=${key}`,{
                    headers: {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                        'X-Content-Type-Options': 'nosniff',
                        'x-requested-with': 'XMLHttpRequest',
                    }
                })
                // Put this in a temporary place until complete somehow
                this.setState({
                    places: this.state.places.concat(placeData.data.results),
                    callsCompletedbyPlacesAPI: this.state.callsCompletedbyPlacesAPI + 1
                })
            } catch(error){
                console.log(error.message);
                alert("Can't Find Attraction on route. Try Another type");
            }
        }
    }

    // Check if route state has been updated. If so, then find attractions
    componentDidUpdate(preProps, PrevState ){
        if(this.state.route !== PrevState.route){
            // Once route has been identifed, determine all attractions along route. Search radius will grow if distance between points become larger. If no attraction has been identified by user, then simply plot route
            if (this.state.route.length !== 0) {
                let foundAtleastOnePlace = false
                if ( this.state.attractions !== undefined){
                    this.state.route.map((steps, count, array) => {
                        if (count > 0) {
                            const previousItem = array[count - 1]
                            let distanceBetween = Math.abs(steps.distance.value - previousItem.distance.value)
                            let tempLocation = `${steps.end_location.lat},${steps.end_location.lng}`
                            if (distanceBetween > 1000 && distanceBetween < 10000) {   
                                this.fetchPlaces(tempLocation, 1000)
                                foundAtleastOnePlace = true
                                PlacesAPICallCounter++;
                            }
                            else if (distanceBetween > 10000 && distanceBetween < 30000) {   
                                this.fetchPlaces(tempLocation, 5000)
                                foundAtleastOnePlace = true
                                PlacesAPICallCounter++;
                            }
                            else if (distanceBetween > 30000 && distanceBetween < 50000) {   
                                this.fetchPlaces(tempLocation, 10000)
                                foundAtleastOnePlace = true
                                PlacesAPICallCounter++;
                            }
                            else if (distanceBetween > 50000 && distanceBetween < 100000) {   
                                this.fetchPlaces(tempLocation, 30000)
                                foundAtleastOnePlace = true
                                PlacesAPICallCounter++;
                            }
                            else if (distanceBetween > 100000) {   
                                this.fetchPlaces(tempLocation, 50000)
                                foundAtleastOnePlace = true
                                PlacesAPICallCounter++;
                            }
                            else if (this.state.route.length === count+1 && foundAtleastOnePlace === false){
                                this.fetchPlaces(tempLocation, 1000)
                                PlacesAPICallCounter++;
                            }
                        }
                    })
                    this.setState({
                        scanThroughRoute: true
                    })
                    // notify renderMap through parent to display loading wheel until all attractions are loaded on map
                    this.props.onLoadingPage()
                }
                // Only share these with parent when route has been identified
                this.props.onOrigin(this.state.origin)
                this.props.onDestination(this.state.destination)
            }
        }  
        if(this.state.places !== PrevState.places){
            // Only begin identifying unique places and share them with parent once places has been sorted through
            if ((this.state.callsCompletedbyPlacesAPI === PlacesAPICallCounter) && (this.state.scanThroughRoute === true)){
                let uniquePlaces = [] 
                let uniqueFound = true
                this.state.places.forEach((place) => {
                    uniqueFound = true
                    if (uniquePlaces.length === 0){
                        uniquePlaces.push(place)
                    } 
                    else {
                        uniquePlaces.forEach((uniPlace) => {
                            if (uniPlace.id === place.id){
                                uniqueFound = false
                            }
                        })
                        if (uniqueFound === true){
                            uniquePlaces.push(place)
                        }
                    }
                })
                this.props.onPlaces(uniquePlaces)
                this.props.onLoadingPage()
            }
        }  
      }

    render(){
        return(
            <section>
                <div class="GeoSuggest">
                    <form onSubmit={this.handleSubmit} id="LocationSearch">
                        <Geosuggest
                            ref={ el => this._geoSuggest = el }
                            placeholder={localStorage.getItem("origin") ? localStorage.getItem("origin") : "A: Starting Point"}
                            onSuggestSelect={ (suggest) => this.onSuggestion('origin', suggest) }
                            location={new google.maps.LatLng(43.653295, -79.382251)}
                            radius="0"
                        /> 
                        <Geosuggest
                            ref={ el => this._geoSuggest = el }
                            placeholder={localStorage.getItem("destination") ? localStorage.getItem("destination") : "B: Destination"}
                            onSuggestSelect={ (suggest) => this.onSuggestion('destination', suggest) }
                            location={new google.maps.LatLng(51.042831, -114.082374)}
                            radius="0"
                        />
                        <input type="text" name="attractions" className="inputAttractions" placeholder={localStorage.getItem("attractions") ? localStorage.getItem("attractions") : "Attractions"} value={this.state.attractions} onChange={this.handleChange} />
                        <br /><Grid item>
                            <ButtonGroup size="small" aria-label="small outlined button group" className="Buttons">
                            <Button type="submit" value="Submit" color="primary" onClick={(event) => this.handleSubmit('Submit', event)} >Submit</Button> 
                            <Button type="clear" value="Clear" color="primary" onClick={(event) => this.handleSubmit('Clear', event)}>Clear All</Button> 
                            </ButtonGroup>
                        </Grid>
                    </form>
                </div>
            </section>
        );
    }
}
export default Location;