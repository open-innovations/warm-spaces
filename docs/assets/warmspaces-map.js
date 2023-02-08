(function(root){
	var OI = root.OI || {};
	if(!OI.ready){
		OI.ready = function(fn){
			// Version 1.1
			if(document.readyState != 'loading') fn();
			else document.addEventListener('DOMContentLoaded', fn);
		};
	}

	function WarmspacesMap(){
		this.title = "WarmspacesMap";
		this.version = "0.1.0";
		this.anchor = {};
		var logger = new Log({"title":this.title,"version":this.version});
		var log = logger.message;
		var nodegroup;
		var map,markerList;
		var el = document.getElementById('map');
		var _obj = this;
		var icons = {'closed':'#bbbbbb','open':'#FF6700','closing-soon':'#D60303','opening-soon':'#F9BC26'};


		// Do we update the address bar?
		this.pushstate = !!(window.history && history.pushState);
		window[(this.pushstate) ? 'onpopstate' : 'onhashchange'] = function(e){ _obj.moveMap(e); };

		this.init = function(){

			// Get the anchor
			this.getAnchor();

			// Create the map
			map = new L.map(el,{
				'center': [this.anchor.lat,this.anchor.lon],
				'zoom': this.anchor.zoom,
				'maxZoom': 18,
				'scrollWheelZoom': true
			});
			map.attributionControl.setPrefix('Data compiled by <a href="https://open-innovations.org/">Open Innovations</a> from <a href="directories">directories of warm spaces</a>');
			var _obj = this;
			// Add callback to the move end event
			map.on('moveend',function(){
				if(_obj.trackmove) _obj.updateMap();
				_obj.trackmove = true;
			});

			// Add a tile layer
			L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png', {
				attribution: 'Tiles &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
				subdomains: 'abcd',
				minZoom: 2,
				maxZoom: 18
			}).addTo(map);
			this.load();
			
			setInterval(function(){ _obj.update(); },60000);
			return this;
		};
		this.updateMap = function(){
			var centre = map.getCenter();
			var s = "";
			var i = 0;
			this.moveMap({},map.getZoom()+'/'+centre.lat.toFixed(5)+'/'+centre.lng.toFixed(5));
			return this;
		};
		
		// Work out where we are based on the anchor tag
		this.moveMap = function(e,a){
			this.getAnchor(a);
			if(!a){
				this.trackmove = false;
				map.setView([this.anchor.lat,this.anchor.lon],this.anchor.zoom);
			}else{
				if(map && this.pushstate) history.pushState({},"Map","?"+this.anchor.str);
			}
			return this;
		};
		// Get the anchor attributes
		this.getAnchor = function(str){
			var id,a,l,i,attr;
			if(!str) str = location.href.split("#")[1];
			if(!str) str = location.search.replace(/logging=true/,"").replace(/\&.*$/g,"").split("?")[1];
			// CHECK
			if(str && str.indexOf("\/") < 0 && S('#'+str).length == 1){
				S('#'+str).addClass('open').find('button').focus();
				return this;
			}
			a = (str) ? str.split('/') : [6,54.69288,-3.35083];
			if(!this.anchor) this.anchor = {};
			this.anchor.lat = a[1];
			this.anchor.zoom = a[0];
			this.anchor.lon = a[2];
			this.anchor.str = str;
			return this;
		};
		this.load = function(){
			return this.loadGeoJSON().loadSources();
		};
		this.loadGeoJSON = function(){
			// Get the data
			var file = "data/places.json";
			fetch(file,{})
			.then(response => { return response.json(); })
			.then(json => {
				this.json = json;
				this.update();
			}).catch(error => {
				log('error','Unable to load file '+file,error);
			});
			return this;
		};
		this.loadSources = function(){
			var file = 'data/sources.json';
			fetch(file,{})
			.then(response => { return response.json(); })
			.then(json => {
				this.sources = json;
				this.update();
			}).catch(error => {
				log('error','Unable to load file '+file,error);
			});
			return this;
		};
		this.formatSource = function(source){
			var html = "";
			if(source=="" || typeof source==="undefined") return '';
			if(source.url) html += '<a href="'+source.url+'" target="_source">';
			if(source.title) html += source.title;
			if(source.url) html += '</a>';
			if(source.map && source.map.url && source.map.url!=source.url){
				html += ' / <a href="'+source.map.url+'" target="_source">Map</a>';
			}
			if(source.register && source.register.url && source.register.url!=source.url){
				html += ' / <a href="'+source.register.url+'" target="_source">Contribute</a>';
			}
			return (html ? '<p class="row footnote"><strong>From:</strong> '+html+'</p>' : '');
		};
		this.makePopup = function(p){
			var html = '';
			var hours = {};
			html += '<h3>'+p.title+'</h3>';
			if(p.address) html += '<p class="address">'+p.address+'</p>';
			if(p.description) html += '<p class="row"><strong>Notes:</strong> '+p.description+'</p>';
			if(p.hours && p.hours.opening){
				hours = processHours(p.hours.opening);
				html += (hours.times ? '<p class="times row"><strong>Opening hours (parsed):</strong></p>'+hours.times : '')+(p.hours._text ? '<p class="times row"><strong>Opening hours (original text):</strong></p><p>'+p.hours._text+'</p>' : '');
			}
			html += this.formatSource(this.sources[p._source]);
			return {'html':html,'hours':hours};
		}
		function makeIcon(cls,colour){
			return {'icon':L.divIcon({
				'className': cls||"",
				'html':	'<svg xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" width="27" height="42" viewBox="0 0 25 41.001" id="svg2" version="1.1"><g id="layer1" transform="translate(1195.4,216.71)"><path style="fill:%COLOUR%;fill-opacity:1;fill-rule:evenodd;stroke:#ffffff;stroke-width:0.1;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;stroke-miterlimit:4;stroke-dasharray:none" d="M 12.5 0.5 A 12 12 0 0 0 0.5 12.5 A 12 12 0 0 0 1.8047 17.939 L 1.8008 17.939 L 12.5 40.998 L 23.199 17.939 L 23.182 17.939 A 12 12 0 0 0 24.5 12.5 A 12 12 0 0 0 12.5 0.5 z " transform="matrix(1,0,0,1,-1195.4,-216.71)" id="path4147" /><ellipse style="opacity:1;fill:#ffffff;fill-opacity:1;stroke:none;stroke-width:1.428;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1" id="path4173" cx="-1182.9" cy="-204.47" rx="5.3848" ry="5.0002" /></g></svg>'.replace(/\%COLOUR\%/,(colour||"#FF6700")),
				'iconSize':	 [27, 42],
				'iconAnchor': [13, 42],
				'popupAnchor': [0, -42]
			}),'class':cls||"",'colour':colour||""};
		}
		for(i in icons) icons[i] = makeIcon(i,icons[i]);

		this.update = function(){
			if(this.json && this.sources){
				if(el.querySelector('.loader')) el.querySelector('.loader').remove();
				
				var nodes = L.markerClusterGroup({
					chunkedLoading: true,
					maxClusterRadius: 60,
					iconCreateFunction: function (cluster) {
						var pins = cluster.getAllChildMarkers();
						var colours = {};
						for(var i = 0; i < pins.length; i++){
							if(!colours[pins[i].options.class]) colours[pins[i].options.class] = 0;
							colours[pins[i].options.class]++;
						}
						var grad = "";
						// The number of colours
						var n = 0;
						var p = 0;
						var f = 1/Math.sqrt(2);
						var ordered = Object.keys(colours).sort(function(a,b){return colours[a]-colours[b]});
						var t = 0;
						for(var i = ordered.length-1; i >= 0; i--){
							c = ordered[i];
							t += colours[c];
							if(grad) grad += ', ';
							grad += icons[c].colour+' '+Math.round(p)+'%';
							p = 100*Math.sqrt(t/pins.length)*f;
							grad += ' '+Math.round(p)+'%';
						}
						return L.divIcon({ html: '<div class="marker-group" style="background:radial-gradient(circle at center, '+grad+');">'+pins.length+'</div>', className: '',iconSize: L.point(40, 40) });
					},
					// Disable all of the defaults:
					spiderfyOnMaxZoom: true,
					showCoverageOnHover: false,
					zoomToBoundsOnClick: true
				});
				
				// Build marker list
				markerList = [];

				// Remove the previous cluster group
				if(nodegroup) map.removeLayer(nodegroup);

				for(var i = 0; i < this.json.length; i++){
					if(typeof this.json[i].lon==="number" && typeof this.json[i].lat==="number"){
						pop = this.makePopup(this.json[i]);
						if(!pop.hours.type) pop.hours.type = "closed";
						if(!icons[pop.hours.type]) icons[pop.hours.type] = makeIcon();
						marker = L.marker([this.json[i].lat,this.json[i].lon],{class:pop.hours.type,icon: icons[pop.hours.type].icon});
						if(!marker.properties) marker.properties = {};
						marker.properties.hours = pop.hours;
						marker.bindPopup(pop.html,{'icon':marker});
						markerList.push(marker);
					}
				}
					
				// Add all the markers we've just made
				nodes.addLayers(markerList);
				map.addLayer(nodes);

				// Save a copy of the cluster group
				this.nodegroup = nodes;
				
			}
			return this;
		};
	}
	/**
	  Adapted from https://github.com/ubahnverleih/simple-opening-hours
	 */
	!function(t){function e(t){return this._original=t,this.parse(t),this}e.prototype.getTable=function(){return"object"==typeof this.openingHours?this.openingHours:{}},e.prototype.isOpen=function(t){var e=this;if("boolean"==typeof this.openingHours)return this.openingHours;var n,r=(t=t||new Date).getDay(),o=t.getHours()+":"+(t.getMinutes()<10?"0"+t.getMinutes():t.getMinutes()),i=0;for(var s in this.openingHours)i==r&&(n=this.openingHours[s]),i++;var a=!1;return n.some(function(t){var n=t.replace(/\+$/,"-24:00").split("-");if(-1!=e.compareTime(o,n[0])&&-1!=e.compareTime(n[1],o))return a=!0,!0}),a},e.prototype.parse=function(t){var e=this;if(/24\s*?\/\s*?7/.test(t))this.openingHours=this.alwaysOpen=!0;else{if(/\s*off\s*/.test(t))return this.openingHours=!1,void(this.alwaysClosed=!0);this.init(),t.toLowerCase().replace(/\s*([-:,;])\s*/g,"$1").split(";").forEach(function(t){e.parseHardPart(t)})}},e.prototype.parseHardPart=function(t){var e=this;"24/7"==t&&(t="mo-su 00:00-24:00");var n=t.split(/\ |\,/),r={},o=[],i=[];for(var s in n.forEach(function(t){e.checkDay(t)&&(0==i.length?o=o.concat(e.parseDays(t)):(o.forEach(function(t){r[t]?r[t]=r[t].concat(i):r[t]=i}),o=e.parseDays(t),i=[])),e.isTimeRange(t)&&("off"==t?i=[]:i.push(t))}),o.forEach(function(t){r[t]?r[t]=r[t].concat(i):r[t]=i}),r)this.openingHours[s]=r[s]},e.prototype.parseDays=function(t){var e=this,n=[];return t.split(",").forEach(function(t){0==(t.match(/\-/g)||[]).length?n.push(t):n=n.concat(e.calcDayRange(t))}),n},e.prototype.init=function(){this.openingHours={su:[],mo:[],tu:[],we:[],th:[],fr:[],sa:[],ph:[]}},e.prototype.calcDayRange=function(t){var e={su:0,mo:1,tu:2,we:3,th:4,fr:5,sa:6},n=t.split("-"),r=e[n[0]],o=e[n[1]],i=[];return this.calcRange(r,o,6).forEach(function(t){for(var n in e)e[n]==t&&i.push(n)}),i},e.prototype.calcRange=function(t,e,n){if(t==e)return[t];for(var r=[t],o=t;o<(t<e?e:n);)o++,r.push(o);return t>e&&(r=r.concat(this.calcRange(0,e,n))),r},e.prototype.isTimeRange=function(t){return!!t.match(/[0-9]{1,2}:[0-9]{2}\+/)||(!!t.match(/[0-9]{1,2}:[0-9]{2}\-[0-9]{1,2}:[0-9]{2}/)||!!t.match(/off/))},e.prototype.checkDay=function(t){var e=["mo","tu","we","th","fr","sa","su","ph"];if(t.match(/\-/g)){var n=t.split("-");if(-1!==e.indexOf(n[0])&&-1!==e.indexOf(n[1]))return!0}else if(-1!==e.indexOf(t))return!0;return!1},e.prototype.compareTime=function(t,e){var n=Number(t.replace(":","")),r=Number(e.replace(":",""));return n>r?1:n<r?-1:0},t.SimpleOpeningHours=e}(window||this);
	function capitalizeFirstLetter(string) { return string.charAt(0).toUpperCase() + string.slice(1); }
	function processHours(times){
		var hours,i,longdays,now,days,hours,cls,newtimes;
		cls = "closed";
		newtimes = "";

		if(times){

			longdays = {"Su":"Sunday","Mo":"Monday","Tu":"Tuesday","We":"Wednesday","Th":"Thursday","Fr":"Friday","Sa":"Saturday","Ph":"Public holiday"};
			//days = {"Su":0,"Mo":1,"Tu":2,"We":3,"Th":4,"Fr":5,"Sa":6};
			days = ['mo','tu','we','th','fr','sa','su','ph'];
			now = new Date();

			hours = new SimpleOpeningHours(times);
		
			for(i = 0; i < days.length; i++){
				if(hours.openingHours[days[i]].length > 0) newtimes += '<li data="'+times+'">'+longdays[capitalizeFirstLetter(days[i])]+': <time>'+hours.openingHours[days[i]]+'</time></li>';
			}
			if(hours.isOpen()) cls = "open";
			if(!hours.isOpen() && hours.isOpen(new Date(now.getTime() + 0.5*3600*1000))) cls = "opening-soon"; // Opens within half an hour
			if(hours.isOpen() && !hours.isOpen(new Date(now.getTime() + 0.5*3600*1000))) cls = "closing-soon"; // Closes within half an hour

		}
		return {'type':cls,'times':(newtimes ? '<ul class="times">'+newtimes+'</ul>':''),'string':times};
	}

	OI.ready(function(){
		root.ws = new WarmspacesMap();
		root.ws.init();
	});

	function Log(opt){
		// Console logging version 2.0
		if(!opt) opt = {};
		if(!opt.title) opt.title = "Log";
		if(!opt.version) opt.version = "2.0";
		this.message = function(...args){
			var t = args.shift();
			if(typeof t!=="string") t = "log";
			var ext = ['%c'+opt.title+' '+opt.version+'%c'];
			if(args.length > 0){
				ext[0] += ':';
				if(typeof args[0]==="string") ext[0] += ' '+args.shift();
			}
			ext.push('font-weight:bold;');
			ext.push('');
			if(args.length > 0) ext = ext.concat(args);
			console[t].apply(null,ext);
		};
		return this;
	}

	root.OI = OI;
})(window || this);