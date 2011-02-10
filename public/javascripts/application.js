/**
 * Notifo app javascript
 */

$(document).ready(function() {
  $('#tabs').tabs({
    cookie: {
      expires: 1
    }
  });
});

$('a.external').live('click', function() {
  var newWindow = window.open(this.href, 'external');
  newWindow.focus();
  return false;
});

$('.register_tab_link').click(function() {
  $('#tabs').tabs("select", 0);
  return false;
});

$('.device_secret_link').click(function() {
  $('#tabs').tabs("select", 1);
  return false;
});

$('.usage_link').click(function() {
  $('#tabs').tabs("select", 2);
  return false;
});

$('.mobile_apps_link').click(function() {
  $('#tabs').tabs("select", 3);
  return false;
});
