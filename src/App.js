import React from 'react';
import Header from './components/Header.js';
import Location from './components/location.js';
import RenderMap from './components/renderMap.js';
import Footer from './components/Footer.js';
import { withScriptjs } from "react-google-maps";
import { GOOGLE_API_KEY } from './constants/roadtrip_api.js';
import './App.css';
import 'mapbox-gl/dist/mapbox-gl.css';

class App extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      origin: {
        lat: undefined,
        lng: undefined
      },
      destination: {
        lat: undefined,
        lng: undefined
      },
      places: [],
      loading: false
    } 
  }
  // Following function required for script conversion recommended by react-google-maps module
  RenderMap = withScriptjs(RenderMap);                  

  // Store array of attractions as places from location component
  onPlaces = (myPlaces) => {
    this.setState({
      places: myPlaces
    })
  }

  // Store origin from location component in a format that can be consumed by renderMap
  onOrigin = (myOrigin) => {
    this.setState({
      origin: {
        lat: parseFloat(myOrigin.split(',', 2)[0]),
        lng: parseFloat(myOrigin.split(',', 2)[1])
      }
    })
  }

  // Store destination from location component in a format that can be consumed by renderMap
  onDestination = (myDestination) => {
    this.setState({
      destination: {
        lat: parseFloat(myDestination.split(',', 2)[0]),
        lng: parseFloat(myDestination.split(',', 2)[1])
      }
    })
  }
  
  // Show loading spinners over the render map
  onLoadingPage = () => {
    console.log(this.state.loading)
    this.setState(prevState => ({
      loading: !prevState.loading
    }))
  }

  // Upon changes to certain states, store it in localstorage
  componentDidUpdate(preProps, PrevState ){
    if(this.state.origin !== PrevState.origin){
      localStorage.setItem('originLatLng', JSON.stringify(this.state.origin));
    }
    if(this.state.destination !== PrevState.destination){
      localStorage.setItem('destinationLatLng', JSON.stringify(this.state.destination));
    }
    if(this.state.places !== PrevState.places){
      localStorage.setItem('placesArray', JSON.stringify(this.state.places));
    }
  }
  
  // If data exist in localStorage, then set it in state
  componentDidMount() {
    if (localStorage.getItem("originLatLng") != null){
      this.setState({
        origin: JSON.parse(localStorage.getItem("originLatLng"))
      })
    }
    if (localStorage.getItem("destinationLatLng") != null){
      this.setState({
        destination: JSON.parse(localStorage.getItem("destinationLatLng"))
      })
    }
    if (localStorage.getItem("placesArray") != null){
      this.setState({
        places: JSON.parse(localStorage.getItem("placesArray") || "[]")
      })
    }
  }  

  render(){
    return ( 
      <section>
        <Header title="Roadtrip Planner" />
         <div className="App">
          <Location onPlaces = {this.onPlaces} onOrigin = {this.onOrigin} onDestination={this.onDestination} onLoadingPage={this.onLoadingPage}/>
          <RenderMap origin={this.state.origin} destination={this.state.destination} places={this.state.places} loading={this.state.loading}
            googleMapURL={`https://maps.googleapis.com/maps/api/js?key=${GOOGLE_API_KEY}`}
            loadingElement={<div style={{ height: `550px` }} />}
          />
        </div>
        <Footer /> 
      </section>
     
    );
  }
}

export default App;
