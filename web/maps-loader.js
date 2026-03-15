(function () {
  const config = window.__NTWAZA_CONFIG__ || {};
  const googleMapsWebKey =
    typeof config.googleMapsWebKey === 'string'
      ? config.googleMapsWebKey.trim()
      : '';

  if (!googleMapsWebKey || (window.google && window.google.maps)) {
    if (!googleMapsWebKey) {
      console.warn(
        'Google Maps web key is not configured. Copy web/maps-config.example.js to web/maps-config.js and set googleMapsWebKey.'
      );
    }
    return;
  }

  var script = document.createElement('script');
  script.src =
    'https://maps.googleapis.com/maps/api/js?key=' +
    encodeURIComponent(googleMapsWebKey) +
    '&callback=__ntwazaMapsReady';
  script.dataset.ntwazaGoogleMaps = 'true';
  // Use a global callback to signal Maps API is ready
  window.__ntwazaMapsReady = function () {
    console.log('Google Maps JS API loaded successfully.');
  };
  document.head.appendChild(script);
})();