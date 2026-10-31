// Hands the provider's callback URL back to the Cue window that opened it
// (flutter_web_auth_2 protocol). Same origin only.
(function () {
  var message = { 'flutter-web-auth-2': window.location.href };
  if (window.opener) {
    window.opener.postMessage(message, window.location.origin);
    window.close();
  } else if (window.parent !== window) {
    window.parent.postMessage(message, window.location.origin);
  } else {
    localStorage.setItem('flutter-web-auth-2', window.location.href);
    window.close();
  }
})();
