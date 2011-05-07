var latlng = new google.maps.LatLng(35.386129, 136.621406);
var myOptions = {
  zoom: 4,
  center: latlng,
  navigationControl:true,
  mapTypeControl:false,
  scaleControl:true,
  streetViewControl:false,
  scrollwheel:false,
  disableDoubleClickZoom:false,
  mapTypeId: google.maps.MapTypeId.ROADMAP
};

map = new google.maps.Map(document.getElementById("mapContainer"), myOptions);

function searchRequested() {
  $("#debug").val($("#feedId").val() + $("#date").val());

  console.log("Search requested");
  
  if ($("#feedId").val() === "") {
    alert("Please input a valid feed id to 'Feed ID'!");
  }

  // Reference:
  // http://api.pachube.com/v2/#read-feed-history
  var pachubeAPIURL = "http://api.pachube.com/v2/feeds/";
  pachubeAPIURL += $("#feedId").val() + ".json?start=";
  pachubeAPIURL += $("#date").val() + "T00:00:00+09:00" + "&end=" + $("#date").val() + "T23:59:59+09:00";
  pachubeAPIURL += "&interval=300";
  pachubeAPIURL += "&callback=?";

  console.log("API URL" + pachubeAPIURL);
  
  var options = {
    key: 'QGYheji3C3f6RofUdVj6cx1i_gVoRUQVZE5Sow1x_aJjGA2svEgeaPknpi8JZYjW'
  };
  
  $.getJSON(pachubeAPIURL, options, function(json, status){
    console.log("Status: " + status);
    console.log(json);

    console.log("Creator: " + json.creator);

    if (json.datastreams[0].datapoints === undefined) {
      alert("No datapoints are available for " + $("#date").val());
      return;
    }

    console.log("Datastream[0]: " + json.datastreams[0].datapoints.length);
    console.log("Datastream[0]: " + [json.datastreams[0].datapoints[0].at, json.datastreams[0].datapoints[0].value, json.datastreams[1].datapoints[0].value, json.datastreams[2].datapoints[0].value]);
    
    for (var i = 0; i < json.datastreams[0].datapoints.length; i++) {
      if (json.datastreams[1].datapoints[i] === undefined || json.datastreams[2].datapoints[i] === undefined) {
        continue;
      }

      var lat = json.datastreams[0].datapoints[i].value;
      var lng = json.datastreams[1].datapoints[i].value;
      var rad = json.datastreams[2].datapoints[i].value;

      if (i === 0) {
        map.panTo(new google.maps.LatLng(lat, lng));
        map.setZoom(9);
      }

      var circleOptions = { 
        center: new google.maps.LatLng(lat, lng), 
        radius: 500,
        strokeWeight: 2,
        strokeColor: "#00aeef",
        strokeOpacity: 1.0,
        fillColor: "#00aeef",
        fillOpacity: 0.5
      };

      var circle = new google.maps.Circle(circleOptions); 
      circle.setMap(map);

      var label = new Label({
        position: new google.maps.LatLng(lat, lng),
        map: map,
        text: parseFloat(rad).toFixed(3) + " µSv/h"
      });
        
      console.log([json.datastreams[0].datapoints[i].at, lat, lng, rad, json.datastreams[1].datapoints[i].at]);
    }

  });

}

