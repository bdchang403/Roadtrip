import React from 'react';
import MoonLoader from 'react-spinners/MoonLoader';
import { css } from '@emotion/core';
import { withGoogleMap, GoogleMap, Marker, InfoWindow, DirectionsRenderer } from "react-google-maps";
const { MarkerWithLabel } = require("react-google-maps/lib/components/addons/MarkerWithLabel");
const google = window.google;

// Setting up override for loading wheel when loading attractions
const override = css`
    position: absolute;
    top: 300px;
    left: 40%;
    z-index: 5;
    display: block;
    margin: 0 auto;
    border-color: #2196f3;
`;

// RenderMap will render the route and points of interest on Google Maps
class RenderMap extends React.Component {
  constructor() {
    super()
    this.state = {
      origin: {
        lat: undefined,
        lng: undefined
      },
      destination: {
        lat: undefined,
        lng: undefined
      },
      directions: undefined,
      loading: false
    };
    this.baseState = this.state;
  }

  // Take origin and destination and plot route in Google Maps
  setDirections = () => {
    const directionsService = new google.maps.DirectionsService();
    const origin = this.props.origin;
    const destination = this.props.destination;
    directionsService.route(
      {
        origin: origin,
        destination: destination,
        travelMode: google.maps.TravelMode.DRIVING
      },
      (result, status) => {
        if (status === google.maps.DirectionsStatus.OK) {
          this.setState({
            directions: result
          });
        } else {
          console.error(`error fetching directions ${result}`);
        }
      }
    );
  }

  // Place markers on Google Maps with details of each attraction
  setMarkers = () => {
    return (
      this.props.places.map((place) => {
        return <MarkerWithLabel
          key={place.place_id}
          position={{
            lat: (typeof place.geometry.location.lat === 'function') ? place.geometry.location.lat() : place.geometry.location.lat,
            lng: (typeof place.geometry.location.lng === 'function') ? place.geometry.location.lng() : place.geometry.location.lng
          }}
          labelAnchor={new google.maps.Point(0, 0)}
          labelStyle={{ backgroundColor: "white", fontSize: "10px", padding: "1px", opacity: 0.85 }}
        >
          <div>
            <b>{place.name}</b>
            <p>Address: {place.vicinity}</p>
            <p>Rating: {place.rating} based on {place.user_ratings_total} reviews</p>
          </div>
        </MarkerWithLabel>
      })
    );
  }

  // Trigger the setDirection function when origin and destination has been defined
  componentDidUpdate(prevProps, PrevState) {
    if (this.props.origin !== prevProps.origin) {
      this.setState({
        origin: this.props.origin
      })
    }
    if (this.props.destination !== prevProps.destination) {
      this.setState({
        destination: this.props.destination
      })
    }
    if (this.state.destination !== PrevState.destination) {
      if (this.state.destination.lat !== undefined) {
        this.setDirections()
      } else {
        this.setState(this.baseState);
      }
    }
    if (this.props.loading !== prevProps.loading) {
      this.setState({
        loading: this.props.loading
      })
    }
  }

  render() {
    // Function defining Google Maps object and adding Directions and Markets layers
    const RenderGoogleMaps = withGoogleMap(props => (
      <GoogleMap
        defaultCenter={{ lat: 43.653295, lng: -79.382251 }}
        defaultZoom={13}
      >
        <DirectionsRenderer
          directions={this.state.directions}
        />
        {console.log(this.props.origin)}
        {console.log(this.props.destination)}
        {(this.props.places.length > 0) ? this.setMarkers() : null}
      </GoogleMap>
    ));
    return (
      <div>
        <MoonLoader
          css={override}
          sizeUnit={"px"}
          size={150}
          color={'#2196f3'}
          loading={this.state.loading}
        />
        <RenderGoogleMaps
          containerElement={<div style={{ height: `550px`, width: '100%' }} />}
          mapElement={<div style={{ height: `100%`, width: '100%' }} />}
        />
      </div>
    );
  }
}

export default RenderMap;