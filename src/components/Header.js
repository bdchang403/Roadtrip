import React from 'react';
import logo from './noun_Road_Trip_2247147.png';

const Header = (props) => {
    return(
        <header className="headerComponent">
            <img src={logo} alt="Logo" />
            <h3>{props.title}</h3>
        </header>
    )
}

export default Header;