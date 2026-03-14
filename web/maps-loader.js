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

  const script = document.createElement('script');
  script.src =
    'https://maps.googleapis.com/maps/api/js?key=' +
    encodeURIComponent(googleMapsWebKey);
  script.async = true;
  script.defer = true;
  script.dataset.ntwazaGoogleMaps = 'true';
  document.head.appendChild(script);
})();