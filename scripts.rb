UPDATE = <<-JS 
updateFrequency = %i;
function checkUpdate() {
  request = new XMLHttpRequest();
  date = new Date(new Date().valueOf() - updateFrequency);
  request.open("HEAD",window.location.href);
  request.setRequestHeader("If-Modified-Since", date.toUTCString());
  request.onreadystatechange = function() {
    if (request.readyState == 4) {
      if (request.status == 304) {
        return;
      } else if (request.status == 204) {
        window.location.reload(true);
      } else {
        return;
      }
    }
  };
  request.send();
  return null;
}
window.setInterval(checkUpdate, updateFrequency);
JS

FLASHY = <<-JS
function flashyTitle() {
  title = document.title;
  function restore() { document.title = title; }
  function white() { document.title = title + " \u2606"; }
  function black() { document.title = title + " \u2605"; }
  black();
  window.setTimeout(white, 500);
  window.setTimeout(black, 1000);
  window.setTimeout(white, 1500);
  window.setTimeout(black, 2000);
  window.setTimeout(white, 2500);
  window.setTimeout(black, 3000);
  window.setTimeout(white, 3500);
  window.setTimeout(restore, 4000);
}
flashyTitle();
JS

TIMEUPDATER = <<-JS
function timestampUpdater() {
  now = new Date().valueOf();
  for (i = 0; i < %u; i++) {
    element = document.getElementById('timestamp' + i);
    stamp = [%s][i];
    msecs = now - stamp;
    cls = '';
    html = '';
    if (msecs < 60*1000) {
      html = 'now';
      cls = 'new';
    } else if (msecs < 60*60*1000) {
      html = ''+Math.floor(msecs/(60*1000))+'m'
      cls = (msecs < 10*60*1000 ? 'new' : '')
    }  else if (msecs < 24*60*60*1000) {
      html = ''+Math.floor(msecs/(60*60*1000))+'h'
    } else if (msecs < 7*24*60*60*1000) {
      html = ''+Math.floor(msecs/(24*60*60*1000))+'d'
    } else {
      html = ''+Math.floor(msecs/(7*24*60*60*1000))+'w'
    }
    element.innerHTML = html;
    element.className = cls;
  }
  return null;
}
timestampUpdater();
window.setInterval(timestampUpdater, 10000);
JS

CHANGE_COLOURING = <<-JS
function changeColoring(className) {
  elements = document.getElementsByClassName(className);
  for (i = 0; i < elements.length; i++) {
    element = elements[i];
    // nextSib = element.nextElementSibling;
    // prevSib = element.previousElementSibling;
    parent = element.parentElement;

    if (null != parent && 'ARTICLE' != parent.tagName) {
      parent.className = parent.className + ' ' + className;
    }
  }
}
changeColoring('old_stuff');
changeColoring('new_stuff');
JS

MARKDOWN_STYLE = <<-CSS
body {
  background-color: #333;
  color: #FFF;
}
#thearticle {
  font-size: 14pt;
  counter-reset: paragraph;
  padding-left: 50px;
  margin-left: 30px; margin-top: 30px;
}

#thearticle > * {
  max-width: 600px;
}

#thearticle > hr {
  margin-left: 0;
}

p:not(.old_stuff) {
  counter-increment: paragraph;
}

p:not(.old_stuff):nth-of-type(5n)::before {
  content: counter(paragraph);
  position: absolute;
  margin-left: -50px;
  color: #777;
  font-size: 70%;
  font-family: monospace;
  font-weight: bold;
  font-style: italic;
}

pre {
  font-size: 11pt;
}

CSS

CHANGE_STYLE = <<-CSS
.old_stuff {
  background-color: #533;
}

.new_stuff {
  background-color: #353;
}

.old_stuff + .old_stuff {
  margin-top: -1em;
  padding-top: 1em;
}

.new_stuff + .new_stuff {
  margin-top: -1em;
  padding-top: 1em;
}

.old_stuff + .new_stuff {
  margin-top: -1em;
}

span.old_stuff + hr {
  border-color: #D33;
}

span.new_stuff + hr {
  border-color: #3D3;
}

.old_stuff.new_stuff {
  background-color: #443;
}

.a_change {
  display: none;
}

CSS

DIR_STYLE = <<-CSS
body {
  background-color: #333;
  color: #FFF;
  font-size: 11pt;
}

#listing {
  margin-left: 50px;
  margin-top: 50px;
  font-family: monospace;
}

a {
  color: #CCF;
  text-decoration: none;
}

#toc {
  border-collapse: collapse;
}

td + td {
  padding-left: 50px;
  text-align: right;
}

tr:hover {
  background-color: #555;
}

.new {
  font-weight: bold;
  color: #F77;
}
CSS

CODE_STYLE = <<-CSS
body {
  background-color: #333;
  color: #FFF;
  font-size: 12pt;
}
#code {
  margin-left: 10px;
  margin-top: 10px;
  font-family: monospace;
  padding: 0px;
}

pre {
  margin: 0px;
}

td.lineNumbers {
  background-color: #444;
  text-align: right;
  padding-left: 5px;
  padding-right: 5px;
}
td + td {
  padding-left: 10px;
}

.kw {
  font-weight: bold;
  color: #CC7;
}

.dv, .bn, .fl {
  color: #F77;
}

.dt, .fn {
  color: #7D7;
}

.st {
  color: #FC6;
  background-color: #532;
}

.ch {
  color: #F77;
  background-color: #532;
}

.ot {
  color: #FC7;
}

.co {
  font-style: italic;
  color: 22D;
}

CSS
