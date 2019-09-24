const proxy = require('http-proxy-middleware');

module.exports = function(app) {
    app.use('*api*', proxy({
      target: 'https://cors-anywhere.herokuapp.com/',
      changeOrigin: true,
    }));
    app.use('/assets', proxy({
        target: 'https://cors-anywhere.herokuapp.com/',
        changeOrigin: true,
      }));
  };