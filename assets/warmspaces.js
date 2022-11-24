/**
	Open Innovations Warm Places Finder
	Version 0.1
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
		this.version = "0.1";
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
					for(f = 0; f < tiles[i].data.features.length; f++){
						if(tiles[i].data.features[f].type==="Feature") geo.features.push(tiles[i].data.features[f]);
					}
				}

				features = geo.features;

				if(typeof attr.finder.region){
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
				else if(feature.geometry.type==="MultiPolygon") polygon = feature.geometry.coordinates[0][0];

				this.setArea(polygon);

			}).catch(error => {
				log('error','Unable to load URL '+url,{'type':'ERROR','extra':{}});
			});
		};
		this.updateList = function(){

			var max = (this.region ? this.sorted.length : Math.min(60,this.sorted.length));
			var acc,logacc,base,frac,options,distance,imin,tmin,i,p,d,html,accuracy;
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
			for(i = 0, added=0; i < this.sorted.length && added < max; i++){
				p = this.sorted[i].properties;
				d = (this.sorted[i].distance) ? Math.ceil(this.sorted[i].distance/accuracy)*accuracy : -1;
				var hours = processHours(p.hours);
				var typ = hours.type;
				if(this.toggles[typ]){
					var cls = this.toggles[typ].class;
					if(this.toggles[typ].checked){
					
						html += '<li tabindex="0" class="'+cls+'"><div>';
						html += (p.url ? '<a href="'+p.url+'/" target="_source">' : '<div>');
						html += '<div class="doublepadded">';
						html += '<h3>'+p.title+'</h3>';
						if(p.address) html += '<p class="address">'+p.address+'</p>';
						html += (d >= 0 ? '<p><span class="dist">'+d+'m</span> or so away</p>' : '');
						if(p.description) html += '<p><strong>Notes:</strong> '+p.description+'</p>';
						if(p.hours){
							html += '<p class="times"><strong>Opening hours:</strong></p>'+hours.times;
						}
						html += '</div>';
						html += (p.url ? '</a>':'</div>');
						html += formatSource(this.sources[p._source]);
						html += '</div></li>';

						added++;
					}
				}else{
					log('warn','No toggle of type '+typ);
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
			
			dlat = 0.03;
			dlon = 0.06;
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
		function processHours(times){
			var i,j,d,dow,now,nth,days,bits,bitpart,cls,okday,today,ranges,r,ts,t1,t2,hh,newtimes,ofmonth,ds,s,e,day;
			cls = "closed";
			newtimes = "";
			if(times){
				var longdays = {"Su":"Sun","Mo":"Mon","Tu":"Tue","We":"Wed","Th":"Thu","Fr":"Fri","Sa":"Sat"};
				days = {"Su":0,"Mo":1,"Tu":2,"We":3,"Th":4,"Fr":5,"Sa":6};
				now = new Date();
				nth = now.getNthOfMonth();
				bits = times.split(/\; /);
				okday = false;
				for(i = 0; i < bits.length; i++){
					(bitpart) = bits[i].split(/ /);
					ds = bitpart[0].split(/-/);
					dow = now.getDay();
					hh = now.getHours() + now.getMinutes()/60;
					today = "";
					for(d in days){
						if(dow==days[d]) today = d;
					}
					okday = false;
					if(ds.length == 1){
						okday = (ds[0].match(today));
					}else{
						s = days[ds[0]];
						e = days[ds[1]];
						if(dow >= s && dow <= e) okday = true;
					}

					ofmonth = "";
					// Check week of month
					bitpart[0] = bitpart[0].replace(/\[([^\]]+)\]/,function(m,p1){
						if(!p1.match(nth)) okday = false;
						ofmonth = "<sup>"+p1+"</sup>";
						return "";
					});
					
					// Format days
					for(j in longdays) bitpart[0] = bitpart[0].replace(new RegExp(j,'g'),longdays[j]);

					newtimes += '<li data="'+times+'">'+bitpart[0]+ofmonth+': '+bitpart[1]+'</li>';

					if(okday){
						ranges = bitpart[1].split(/,/);
						//console.log(bits,bitpart,'matches this day of week');
						for(r = 0; r < ranges.length; r++){
							ts = ranges[r].split(/-/);
							t1 = ts[0].split(/:/);
							t2 = ts[1].split(/:/);
							t1 = parseInt(t1[0]) + parseInt(t1[1])/60;
							t2 = parseInt(t2[0]) + parseInt(t2[1])/60;
							if(t1 <= hh && t2 > hh) cls = "open";
							if(hh < t1 && hh > t1-0.5) cls = "opening-soon";
							if(hh < t2 && hh > t2-0.25) cls = "closing-soon";
						}
					}
				}
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
		this.version = "0.1";

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
				w = Math.min(e,opts.limits.W);
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
		this.addToMap = function(geojson,config){
			var i;

			if(opts.map){

				layerGroup.addTo(opts.map);
				
				var colour = config.colour||"#e6007c";

				function createIcon(data, category){
					return L.divIcon({
						'className': 'oi-map-marker',
						'html': '<svg overflow="visible" width="24" height="40" class="oi-map-marker" style="transform:translate3d(0,0,0)"><path d="M 0,0 L -10.84,-22.86 A 12 12 1 1 1 10.84,-22.86 L 0,0 z" fill="{fill}" fill-opacity="1"></path><ellipse cx="0" cy="-27.5" rx="4" ry="4" fill="white"></ellipse></svg>'.replace(/\{fill\}/,colour),
						iconSize: [0, 0],
						iconAnchor: [0, 0]
					});
				}

				var mapIcon = createIcon();

				if(geojsonlayer) layerGroup.removeLayer(geojsonlayer);
				
				if(typeof L.markerClusterGroup==="function"){

					geojsonlayer = L.markerClusterGroup({
						chunkedLoading: true,
						maxClusterRadius: 60,
						iconCreateFunction: function (cluster){
							return L.divIcon({ html: '<div class="marker-group" style="background:'+colour+';color:white;border-radius:100%;text-align:center;font-size:0.8em;line-height:2.5em;width:2.5em;opacity:0.85;">'+cluster.getChildCount()+'</div>', className: '' });
						},
						disableClusteringAtZoom: 17,
						spiderfyOnMaxZoom: true,
						showCoverageOnHover: false,
						zoomToBoundsOnClick: true
					});
					var markerList = [];
          var ll,tempmark;
					for(i = 0; i < geojson.features.length; i++){
						if(geojson.features[i].geometry.type=="Point"){
							ll = geojson.features[i].geometry.coordinates;
							tempmark = L.marker([ll[1],ll[0]],{icon: mapIcon});
							markerList.push(tempmark);
						}
					}
					geojsonlayer.addLayers(markerList);

				}else if(typeof PruneClusterForLeaflet==="function"){

					// https://github.com/SINTEF-9012/PruneCluster
					geojsonlayer = new PruneClusterForLeaflet();
					
					geojsonlayer.BuildLeafletClusterIcon = function(cluster) {
						var max,i,c,fs,c2,c3,n,s;
						var population = cluster.population; // the number of markers inside the cluster
						max = 0;
						for(i = 0; i < this.Cluster._clusters.length; i++) max = Math.max(max,this.Cluster._clusters[i].population);
						//c = OI.ColourScale.getColour(1-population/max);
						c = OI.ColourScale.getColour(1);
						c2 = c.colour.replace(",1)",",0.5)");
						c3 = c.colour.replace(",1)",",0.2)");
						fs = 0.7 + Math.sqrt(population/max)*0.3;
						n = (""+population).length;
						if(n==1) s = 1.8;
						else if(n==2) s = 2.2;
						else if(n==3) s = 2.6;
						else if(n==4) s = 3;
						else if(n==5) s = 3;
						return L.divIcon({ html: '<div class="marker-group" style="background:'+c.colour+';color:'+(c.contrast)+';box-shadow:0 0 0 0.2em '+c2+',0 0 0 0.4em '+c3+';font-family:Poppins;border-radius:100%;text-align:center;font-size:'+fs+'em;line-height:'+s+'em;width:'+s+'em;opacity:0.85;">'+population+'</div>', className: '' });
					};
					
					for(i = 0; i < geojson.features.length; i++){
						if(geojson.features[i].geometry.type=="Point"){
							ll = geojson.features[i].geometry.coordinates;
							var marker = new PruneCluster.Marker(ll[1],ll[0]);
							marker.data.icon = createIcon;
							marker.category = 0;
							geojsonlayer.RegisterMarker(marker);
						}
					}
					
				}else{

					geojsonlayer = L.geoJson(geojson,{
						pointToLayer(feature, latlng) {
							return L.marker(latlng, {icon: mapIcon });
						}
					});					

				}

				layerGroup.addLayer(geojsonlayer);

			}
			return this;
		};
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
