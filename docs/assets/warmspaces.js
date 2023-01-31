/**
	Open Innovations Warm Places Finder
	Version 0.2.1
 */
(function(root){

	var OI = root.OI || {};
	if(!OI.ready){
		OI.ready = function(fn){
			// Version 1.1
			if(document.readyState != 'loading') fn();
			else document.addEventListener('DOMContentLoaded', fn);
		};
	}
	function WarmSpacesFinder(opts){
		if(!opts) opts = {};

		this.name = "Open Innovations Warm Spaces Finder";
		this.version = "0.2.1";
		var logger = new Log({"title":this.name,"version":this.version});
		var log = logger.message;

		if(!opts.el){
			log("error","No output area to attach to.");
			return this;
		}
		
		// Create geo-location button
		this.btn = document.getElementById('find');
		if(!this.btn){
			this.btn = document.createElement('button');
			this.btn.innerHTML = "Find spaces near me";
			this.btn.classList.add('c13-bg');
			opts.el.appendChild(this.btn);
		}
		var _obj = this;
		this.btn.addEventListener('click',function(e){ e.preventDefault(); e.stopPropagation(); _obj.getLocation(); });

		// Create an element before the list
		this.key = document.getElementById('key-holder');
		this.toggles = {};
		var keyitems = document.querySelectorAll('#key .keyitem input');
		for(i = 0; i < keyitems.length; i++){
			this.toggles[keyitems[i].getAttribute('data')] = new Toggle(keyitems[i],{
				'this':this,
				'callback':function(e){ this.updateList(); }
			});
		};

		// Create an element before the list
		this.loader = document.createElement('div');
		this.loader.classList.add('loader');
		opts.el.appendChild(this.loader);

		// Create list output area
		this.list = document.createElement('ul');
		this.list.classList.add('list','grid');

		// Create a tiled data layer object
		this.tiler = OI.TiledDataLayer(merge({
			'url':'https://odileeds.github.io/osm-geojson/tiles/bins/{z}/{x}/{y}.geojson',
			'zoomLevels': [12],
			'finder': this,
			'loaded':function(tiles,attr){
				var i,geo,lat,lon,f,features,sorted,c;
				log('info','There are '+tiles.length+' tiles.');
				geo = {'type':'FeatureCollection','features':[]};
				for(i = 0; i < tiles.length; i++){
					if(tiles[i].data && tiles[i].data.features){
						for(f = 0; f < tiles[i].data.features.length; f++){
							if(tiles[i].data.features[f].type==="Feature") geo.features.push(tiles[i].data.features[f]);
						}
					}
				}

				features = geo.features;

				if(attr.finder.region){
					sorted = [];
					log('info','Checking if in region',attr.finder.region)
					for(i = 0; i < features.length; i++){
						if(attr.finder.region.contains(features[i].geometry.coordinates[0],features[i].geometry.coordinates[1])) sorted.push(features[i]);
					}
					sorted = sorted.sort(function(a,b){return a.properties.title > b.properties.title;});
				}else{
					lat = attr.finder.lat;
					lon = attr.finder.lon;

					for(i = 0; i < features.length; i++){
						c = features[i].geometry.coordinates;
						features[i].distance = greatCircle([lon,lat],c);
					}
					sorted = features.sort(function(a,b){return a.distance - b.distance;});
				}

				// Build list
				attr.finder.sorted = sorted;
				attr.finder.updateList();
			}
		},opts.tiles||{}));
		
		// Set or load the sources
		if(typeof opts.sources==="object"){
			this.sources = opts.sources;
		}else{
			if(typeof opts.sources==="string"){
				// Parse unprocessed Jekyll string
				opts.sources = opts.sources.replace(/\{% include_relative ([^\%]+) %\}/,function(m,p1){ return p1; });
			}
			var f = opts.sources||"data/sources.json";
			fetch(f,{})
			.then(response => { return response.json(); })
			.then(json => {
				this.sources = json;
				this.init();
			}).catch(error => {
				log("error",'Unable to load sources from '+f);
			});
		}
		this.loadArea = function(url){
			fetch(url,{})
			.then(response => { return response.json(); })
			.then(feature => {
				
				var polygon;
				if(feature.geometry.type==="Polygon") polygon = feature.geometry.coordinates[0];
				else if(feature.geometry.type==="MultiPolygon"){
					// Find biggest polygon
					var max = 0;
					var f,idx = 0;
					for(f = 0; f < feature.geometry.coordinates.length; f++){
						if(feature.geometry.coordinates[f][0].length > max){
							max = feature.geometry.coordinates[f][0].length;
							idx = f;
						}
					}
					polygon = feature.geometry.coordinates[idx][0];
				}
				this.setArea(polygon);

			}).catch(error => {
				log('error','Unable to load URL '+url,{'type':'ERROR','extra':{}});
			});
		};
		this.updateList = function(){

			var max = (this.region ? this.sorted.length : Math.min(60,this.sorted.length));
			var acc,logacc,base,frac,options,distance,imin,tmin,i,p,d,html,accuracy,lat,lon;
			// We want to round to the accuracy of the geolocation
			acc = (this.location ? this.location.coords.accuracy : 50);
			logacc = Math.log10(acc);
			base = Math.floor(logacc);
			frac = logacc - base;
			// We now want to check whether frac falls closest to 1, 2, 5, or 10 (in log
			// space). There are more efficient ways of doing this but this is just for clarity.
			options = [1,2,5,10];
			distance = new Array(options.length);
			imin = -1;
			tmin = 1e100;
			for(i = 0; i < options.length; i++){
				distance[i] = Math.abs(frac - Math.log10(options[i]));
				if(distance[i] < tmin){
					tmin = distance[i];
					imin = i;
				}
			}
			// Now determine the actual spacing
			accuracy = Math.pow(10,(base))*options[imin];
			log('info','Location accuracy set to '+accuracy+'m');
			// Limit uncertainty as it can cause confusion when it is very large
			if(accuracy > 200) accuracy = 200;

			html = '';
			var nopen = 0;
			for(i = 0, added=0; i < this.sorted.length && added < max; i++){
				p = this.sorted[i].properties;
				d = formatDistance(this.sorted[i].distance,accuracy);
				var hours = {};
				if(p.hours && p.hours.opening) hours = processHours(p.hours.opening);
				var typ = hours.type;
				if(!typ) typ = "unknown";
				if(this.toggles[typ]){
					var cls = this.toggles[typ].class;
					if(this.toggles[typ].checked){

						if(typ == "open" && nopen == 0) cls += ' nearest';

						lat = this.sorted[i].geometry.coordinates[1];
						lon = this.sorted[i].geometry.coordinates[0];

						html += '<li tabindex="0" class="'+cls+'"><div>';
						html += '<div>';
						html += '<div class="doublepadded">';
						html += '<h3>'+(p.url ? '<a href="'+p.url+'/" target="_source">' : '')+p.title+(p.url ? '</a>' : '')+'</h3>';
						if(p.address) html += '<p class="address">'+p.address+'</p>';
						html += (d && d!="m" ? '<p><strong>Distance:</strong> about <span class="dist">'+d+'</span> away</p>' : '');
						if(p.address) html += '<p><strong>Map</strong>: <a href="https://www.openstreetmap.org/#map=18/'+lat+'/'+lon+'" target="_osm">OpenStreetMap</a> | <a href="https://www.google.com/maps/@'+lat+','+lon+',18z" target="_gmap">Google</a> | <a href="https://www.bing.com/maps/?cp='+lat+'%7E'+lon+'&lvl=18" target="_bing">Bing</a></p>';
						if(p.description) html += '<p><strong>Notes:</strong> '+p.description+'</p>';
						if(p.hours && p.hours._text){
							html += (hours.times ? '<p class="times"><strong>Opening hours (parsed):</strong></p>'+hours.times : '')+(p.hours._text ? '<p class="times"><strong>Opening hours (original text):</strong></p><p>'+p.hours._text+'</p>' : '');
						}
						html += '</div>';
						html += '</div>';
						html += formatSource(this.sources[p._source]);
						html += '</div></li>';

						added++;
						if(typ == "open") nopen++;
					}
				}else{
					log('warn','No toggle of type '+typ,p);
				}
			}
			this.list.innerHTML = html;
			
			opts.el.appendChild(this.list);

			this.loader.innerHTML = '';
			this.key.style.display = "block";
			
			return this;
		};
		this.loadGSS = function(code){
			var gss = {
				'PCON':{
					'title':'Parliamentary Constituencies (2017)',
					'patterns':[/^E14[0-9]{6}$/,/^W07[0-9]{6}$/,/^S14[0-9]{6}$/,/^N06[0-9]{6}$/],
					'geojson':'https://open-innovations.github.io/geography-bits/data/PCON17CD/{{gss}}.geojsonl'
				},
				'WD':{
					'title': 'Wards (2021)',
					'patterns':[/^E05[0-9]{6}$/,/^W05[0-9]{6}$/,/^S13[0-9]{6}$/,/^N08[0-9]{6}$/],
					'geojson': 'https://open-innovations.github.io/geography-bits/data/WD21CD/{{gss}}.geojsonl'
				},
				'LAD':{
					'title': 'Local Authority Districts (2021)',
					'patterns':[/^E06[0-9]{6}$/,/^W06[0-9]{6}$/,/^S12[0-9]{6}$/,/^E07[0-9]{6}$/,/^E08[0-9]{6}$/,/^E09[0-9]{6}$/],
					'geojson': 'https://open-innovations.github.io/geography-bits/data/LAD21CD/{{gss}}.geojsonl'
				}
			};
			var g,m,url="";
			for(g in gss){
				gss[g].matches = {};
				for(m = 0; m < gss[g].patterns.length; m++){
					if(code.match(gss[g].patterns[m])){
						url = gss[g].geojson.replace(/\{\{gss\}\}/,code);
						continue;
					}
				}
			}
			if(url) this.loadArea(url);
			return this;
		};
		this.init = function(){
			if(location.search){
				var m = location.search.match(/gss=([^\&]*[EWNS][0-9]{8})/);
				if(m.length==2) this.loadGSS(m[1]);
			}

			return this;
		};
		this.getLocation = function(){ this.startLocation("getCurrentPosition"); };
		this.startLocation = function(type){

			this.loader.innerHTML = '<svg version="1.1" width="64" height="64" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg"><g transform="matrix(.11601 0 0 .11601 -49.537 -39.959)"><path d="m610.92 896.12m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="-0.83333s" repeatCount="indefinite" /></path><path d="m794.82 577.6m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="-0.6666s" repeatCount="indefinite" /></path><path d="m1162.6 577.6m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="-0.5s" repeatCount="indefinite" /></path><path d="m1346.5 896.12m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="-0.3333s" repeatCount="indefinite" /></path><path d="m1162.6 1214.6m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="-0.1666s" repeatCount="indefinite" /></path><path d="m794.82 1214.6m183.9-106.17-183.9-106.17-183.9 106.17v212.35l183.9 106.17 183.9-106.17z" fill="black"><animate attributeName="opacity" values="1;0;0" keyTimes="0;0.7;1" dur="1s" begin="0s" repeatCount="indefinite" /></path></g></svg>';

			if(!type) type = "watchPosition";
			// Start watching the user location
			var _obj = this;
			log('info','Getting location...');
			this.watchID = navigator.geolocation[type](function(position){
				_obj.updateLocation(position);
			},function(){
				log('error',"Having trouble finding your location.");
			},{
				enableHighAccuracy: true,
				maximumAge				: 30000,
				timeout					 : 27000
			});
		};
		this.stopLocation = function(){
			navigator.geolocation.clearWatch(this.watchID);
			return this;
		};
		this.updateLocation = function(position){
			this.location = position;
			delete this.region;
			this.setLocation(position.coords.latitude,position.coords.longitude);
		};
		this.setArea = function(poly){
			this.region = new Region(poly);
			this.setBounds(this.region.boundingBox());
			return this;
		};
		this.setBounds = function(bounds){
			log('info','Set bounds',bounds);
			delete this.lat;
			delete this.lon;
			if(bounds) this.tiler.getTiles(bounds,opts.tiles.zoomLevels[0]);
			return this;			
		};
		this.setLocation = function(lat,lon){
			log('info','Set location',lat,lon);
			var dlat,dlon,bounds;
			this.lat = lat;
			this.lon = lon;
			
			dlat = (10/111);	// 5km horizontally or vertically 
			dlon = 2*dlat;
			bounds = {"_southWest": {
					"lat": this.lat-dlat,
					"lng": this.lon-dlon
				},
				"_northEast": {
					"lat": this.lat+dlat,
					"lng": this.lon+dlon
				}
			};

			this.tiler.getTiles(bounds,opts.tiles.zoomLevels[0]);
			return this;
		};
		function formatSource(source){
			var html = "";
			if(source=="") return '';
			if(source.url) html += '<a href="'+source.url+'" target="_source">';
			if(source.title) html += source.title;
			if(source.url) html += '</a>';
			if(source.map && source.map.url && source.map.url!=source.url){
				html += ' / <a href="'+source.map.url+'" target="_source">Map</a>';
			}
			if(source.register && source.register.url && source.register.url!=source.url){
				html += ' / <a href="'+source.register.url+'" target="_source">Contribute</a>';
			}
			return (html ? '<div class="source b2-bg"><strong>From:</strong> '+html+'</div>' : '');
		}
		Date.prototype.getNthOfMonth = function(){
			var dd = new Date(this),
				day = this.getDate(),
				today = this.getDay(),
				n = 0;
			var i,d;
			for(i = 1; i <= day; i++){
				dd.setDate(i);
				d = dd.getDay();
				if(d==today) n++;
				
			}
			return n;
		};
		
		/**
		  Adapted from https://github.com/ubahnverleih/simple-opening-hours
		 */
		!function(t){function e(t){return this._original=t,this.parse(t),this}e.prototype.getTable=function(){return"object"==typeof this.openingHours?this.openingHours:{}},e.prototype.isOpen=function(t){var e=this;if("boolean"==typeof this.openingHours)return this.openingHours;var n,r=(t=t||new Date).getDay(),o=t.getHours()+":"+(t.getMinutes()<10?"0"+t.getMinutes():t.getMinutes()),i=0;for(var s in this.openingHours)i==r&&(n=this.openingHours[s]),i++;var a=!1;return n.some(function(t){var n=t.replace(/\+$/,"-24:00").split("-");if(-1!=e.compareTime(o,n[0])&&-1!=e.compareTime(n[1],o))return a=!0,!0}),a},e.prototype.parse=function(t){var e=this;if(/24\s*?\/\s*?7/.test(t))this.openingHours=this.alwaysOpen=!0;else{if(/\s*off\s*/.test(t))return this.openingHours=!1,void(this.alwaysClosed=!0);this.init(),t.toLowerCase().replace(/\s*([-:,;])\s*/g,"$1").split(";").forEach(function(t){e.parseHardPart(t)})}},e.prototype.parseHardPart=function(t){var e=this;"24/7"==t&&(t="mo-su 00:00-24:00");var n=t.split(/\ |\,/),r={},o=[],i=[];for(var s in n.forEach(function(t){e.checkDay(t)&&(0==i.length?o=o.concat(e.parseDays(t)):(o.forEach(function(t){r[t]?r[t]=r[t].concat(i):r[t]=i}),o=e.parseDays(t),i=[])),e.isTimeRange(t)&&("off"==t?i=[]:i.push(t))}),o.forEach(function(t){r[t]?r[t]=r[t].concat(i):r[t]=i}),r)this.openingHours[s]=r[s]},e.prototype.parseDays=function(t){var e=this,n=[];return t.split(",").forEach(function(t){0==(t.match(/\-/g)||[]).length?n.push(t):n=n.concat(e.calcDayRange(t))}),n},e.prototype.init=function(){this.openingHours={su:[],mo:[],tu:[],we:[],th:[],fr:[],sa:[],ph:[]}},e.prototype.calcDayRange=function(t){var e={su:0,mo:1,tu:2,we:3,th:4,fr:5,sa:6},n=t.split("-"),r=e[n[0]],o=e[n[1]],i=[];return this.calcRange(r,o,6).forEach(function(t){for(var n in e)e[n]==t&&i.push(n)}),i},e.prototype.calcRange=function(t,e,n){if(t==e)return[t];for(var r=[t],o=t;o<(t<e?e:n);)o++,r.push(o);return t>e&&(r=r.concat(this.calcRange(0,e,n))),r},e.prototype.isTimeRange=function(t){return!!t.match(/[0-9]{1,2}:[0-9]{2}\+/)||(!!t.match(/[0-9]{1,2}:[0-9]{2}\-[0-9]{1,2}:[0-9]{2}/)||!!t.match(/off/))},e.prototype.checkDay=function(t){var e=["mo","tu","we","th","fr","sa","su","ph"];if(t.match(/\-/g)){var n=t.split("-");if(-1!==e.indexOf(n[0])&&-1!==e.indexOf(n[1]))return!0}else if(-1!==e.indexOf(t))return!0;return!1},e.prototype.compareTime=function(t,e){var n=Number(t.replace(":","")),r=Number(e.replace(":",""));return n>r?1:n<r?-1:0},t.SimpleOpeningHours=e}(window||this);
		function capitalizeFirstLetter(string) { return string.charAt(0).toUpperCase() + string.slice(1); }
		function processHours(times){
			var i,longdays,now,days,hours,cls,newtimes;
			cls = "closed";
			newtimes = "";

			if(times){

				longdays = {"Su":"Sun","Mo":"Mon","Tu":"Tue","We":"Wed","Th":"Thu","Fr":"Fri","Sa":"Sat","Ph":"Public holiday"};
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
			return {'type':cls,'times':(newtimes ? '<ul class="times">'+newtimes+'</ul>':'')};
		}
		
		return this;
	}
	function Toggle(inp,opts){
		if(!opts) opts = {};
		var cls = inp.closest('li').getAttribute('class').replace(/ keyitem.*$/,"");
		this.checked = inp.checked;
		this.type = inp.getAttribute('data');
		this.class = cls;
		var _obj = this;
		inp.addEventListener('change',function(e){
			_obj.checked = inp.checked;
			if(typeof opts.callback==="function") opts.callback.call(opts.this||this);
		});
		return this;
	}

	// Centroid calculation from https://stackoverflow.com/questions/16282330/find-centerpoint-of-polygon-in-javascript
	function Region(points) {
		this.points = points || [];
		this.length = points.length;
	}
	Region.prototype.area = function () {
		var area = 0,i,j,point1,point2;
		for(i = 0, j = this.length - 1; i < this.length; j=i,i++){
			point1 = this.points[i];
			point2 = this.points[j];
			area += point1[0] * point2[1];
			area -= point1[1] * point2[0];
		}
		area /= 2;

		return area;
	};
	Region.prototype.contains = function(x,y){
		var i, j, c = false;
		var nvert = this.length;
		for(i = 0, j = nvert-1; i < nvert; j = i++){
			vertx = this.points[i][0];
			verty = this.points[i][1];
			if(((this.points[i][1] > y) != (this.points[j][1] > y)) && (x < (this.points[j][0]-this.points[i][0]) * (y - this.points[i][1]) / (this.points[j][1] - this.points[i][1]) + this.points[i][0])) c = !c;
		}
		return c;
	};
	Region.prototype.centroid = function () {
		var x = 0, y = 0, i, j, f, point1, point2;
		for(i = 0, j = this.length - 1; i < this.length; j=i,i++){
			point1 = this.points[i];
			point2 = this.points[j];
			f = point1[0] * point2[1] - point2[0] * point1[1];
			x += (point1[0] + point2[0]) * f;
			y += (point1[1] + point2[1]) * f;
		}

		f = this.area() * 6;

		return [x / f, y / f];
	};
	Region.prototype.boundingBox = function(){
		var i,N=-90,E=-180,S=90,W=180,j;
		for(i = 0, j = this.length - 1; i < this.length; j=i,i++){
			N = Math.max(N,this.points[i][1]);
			S = Math.min(S,this.points[i][1]);
			E = Math.max(E,this.points[i][0]);
			W = Math.min(W,this.points[i][0]);
		}
		return {'_southWest':{'lat':S,'lng':W},'_northEast':{'lat':N,'lng':E},'N':N,'S':S,'E':E,'W':W};
	};
	function greatCircle(a,b){
		// Inputs [longitude,latitude]
		var d2r = Math.PI/180;
		var R = 6.3781e6; // metres
		var f1 = a[1]*d2r;
		var f2 = b[1]*d2r;
		var dlat = (a[1]-b[1])*d2r;
		var dlon = (a[0]-b[0])*d2r;

		var d = Math.sin(dlat/2) * Math.sin(dlat/2) +
				Math.cos(f1) * Math.cos(f2) *
				Math.sin(dlon/2) * Math.sin(dlon/2);
		var c = 2 * Math.atan2(Math.sqrt(d), Math.sqrt(1-d));

		return R * c;
	}		
	function TiledDataLayer(opts){
		if(!opts) opts = {};
		this.title = "TiledDataLayer";
		this.version = "0.1a";

		var logger = new Log({"title":this.title,"version":this.version});
		var log = logger.message;

		if(!opts.url){
			log("error",'No url provided for data layer');
			return this;
		}

		var tiles = [];
		var tileLookup = {};
		
		if(typeof L==="undefined") log("warn",'No map to attach to');

		var R = 6378137, sphericalScale = 0.5 / (Math.PI * R);

		function tile2lon(x,z){ return (x/Math.pow(2,z)*360-180); }
		function tile2lat(y,z){ var n=Math.PI-2*Math.PI*y/Math.pow(2,z); return (180/Math.PI*Math.atan(0.5*(Math.exp(n)-Math.exp(-n)))); }

		/* Adapted from: https://gist.github.com/mourner/8825883 */
		this.xyz = function(bounds, z) {

			if(typeof bounds.N==="number") bounds = {'_northEast':{'lat':bounds.N,'lng':bounds.E},'_southWest':{'lat':bounds.S,'lng':bounds.W}};

			var n,s,e,w,x,y,t,min,max;
			// Find bounds
			n = bounds._northEast.lat;
			s = bounds._southWest.lat;
			e = bounds._northEast.lng;
			w = bounds._southWest.lng;
			// Reduce bounds to any limits that have been set
			if(opts.limits){
				n = Math.min(n,opts.limits.N);
				s = Math.max(s,opts.limits.S);
				e = Math.min(e,opts.limits.E);
				w = Math.max(w,opts.limits.W);
			}

			min = project(n, w, z);
			max = project(s, e, z);
			t = [];
			for(x = min.x; x <= max.x; x++) {
				for(y = min.y; y <= max.y; y++) t.push({ x: x, y: y, z: z, b: {'_northEast':{'lat':tile2lat(y,z),'lng':tile2lon(x+1,z)},'_southWest':{'lat':tile2lat(y+1,z),'lng':tile2lon(x,z)}} });
			}
			return t;
		};
		if(opts.map){
			var layerGroup = new L.LayerGroup();
			var geojsonlayer;
		}
		function newFetch(url, o, cb){
			fetch(url,{})
			.then(response => { return response.json(); })
			.then(json => {
				tileLookup[o.z][o.y][o.x].loaded = true;
				tileLookup[o.z][o.y][o.x].data = json;
				if(typeof cb==="function") cb.call(this);
			}).catch(error => {
				tileLookup[o.z][o.y][o.x].loaded = true;
				tileLookup[o.z][o.y][o.x].data = {'type':'FeatureCollection','features':[]};
				if(typeof cb==="function") cb.call(this);
				log("error",'Unable to load URL '+url);
			});
			return;
		}
		this.normaliseZoom = function(z){
			var idx,min,i,v,zoom;
			// Take a default zoom level
			zoom = (typeof opts.zoom==="number") ? opts.zoom : 10;
			// If a zoom is provided, set it
			if(typeof z==="number") zoom = z;
			// Find the nearest zoom level to the required zoom
			idx = -1;
			min = Infinity;
			for(i = 0; i < opts.zoomLevels.length; i++){
				v = Math.abs(zoom-opts.zoomLevels[i]);
				if(v < min){
					idx = i;
					min = v;
				}
			}
			if(idx >= 0) zoom = opts.zoomLevels[idx];
			return zoom;
		};
		this.getTiles = function(bounds,z){
			z = this.normaliseZoom(z);
			var i,x,y;
			tiles = this.xyz(bounds,z);
			if(!tileLookup[z]) tileLookup[z] = {};

			function loaded(){
				// Check if tiles loaded
				var ok = true;
				for(i = 0; i < tiles.length; i++){
					if(!tileLookup[tiles[i].z][tiles[i].y][tiles[i].x].loaded) ok = false;
				}
				if(!ok) return this;
				
				if(typeof opts.loaded==="function"){
					var t = [];
					var tile;
					for(i = 0; i < tiles.length; i++){
						tile = JSON.parse(JSON.stringify(tiles[i]));
						tile.data = tileLookup[tiles[i].z][tiles[i].y][tiles[i].x].data;
						t.push(tile);
					}
					opts.loaded.call(opts.this||this,t,opts,{'bounds':bounds,'z':z});
				}
				return this;
			}

			for(i = 0; i < tiles.length; i++){
				y = tiles[i].y;
				x = tiles[i].x;
				if(!tileLookup[z][y]) tileLookup[z][y] = {};
				if(!tileLookup[z][y][x]){
					tileLookup[z][y][x] = {
						'loaded': false,
						'url': opts.url.replace(/\{x\}/g,x).replace(/\{y\}/g,y).replace(/\{z\}/g,z)
					};
					//log('info','Get '+tileLookup[z][y][x].url);
					tileLookup[z][y][x].fetch = newFetch.call(this,tileLookup[z][y][x].url,{'x':x,'y':y,'z':z},loaded);
				}
			}
			return loaded.call(this);
		};

		/* 
		Adapts a group of functions from Leaflet.js to work headlessly
		https://github.com/Leaflet/Leaflet
		*/
		function project(lat,lng,zoom) {
			var d = Math.PI / 180,
			max = 1 - 1E-15,
			sin = Math.max(Math.min(Math.sin(lat * d), max), -max),
			scale = 256 * Math.pow(2, zoom);

			var point = {
				x: R * lng * d,
				y: R * Math.log((1 + sin) / (1 - sin)) / 2
			};

			point.x = tiled(scale * (sphericalScale * point.x + 0.5));
			point.y = tiled(scale * (-sphericalScale * point.y + 0.5));

			return point;
		}

		function tiled(num) {
			return Math.floor(num/256);
		}
		
		return this;
	}
	function formatDistance(d,accuracy){
		if(typeof d==="number") d = Math.ceil(d/accuracy)*accuracy
		else d = "";
		if(d > 1000) d = parseFloat((d/1000).toFixed(1))+'km';
		else d = d+'m';
		return d;
	}
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


	// Recursively merge properties of two objects 
	function merge(obj1, obj2){
		for(var p in obj2){
			try{
				if(obj2[p].constructor==Object) obj1[p] = merge(obj1[p], obj2[p]);
				else obj1[p] = obj2[p];
			}catch(e){ obj1[p] = obj2[p]; }
		}
		return obj1;
	}

	OI.TiledDataLayer = function(opts){ return new TiledDataLayer(opts); };	
	OI.WarmSpacesFinder = function(opts){ return new WarmSpacesFinder(opts); };	

	root.OI = OI||root.OI||{};
	
})(window || this);
