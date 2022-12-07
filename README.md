# Warm spaces

With a cost-of-living crisis and an energy-price crisis, lots of people will be cold this winter and looking for warm places to go. Several different groups have started collating directories of warm spaces. This duplicates work and means each single resource is less complete. Also, the data isn't published openly but instead mostly displayed via map interfaces which tend to create quite large page loads - not great for anyone using limited mobile data plans.

There are two competing requirements kept in mind when building the finder: 1) minimise data transfer; 2) maximise privacy. Those struggling with the cost of living are perhaps more likely to have older devices and limited data plans. So, we've designed the initial page load to be many times smaller than most of the existing directories of warm spaces. We've also split the data into "tiles" to help limit further data use when someone searches for a place. At the same time, we do our best not to preserve as much privacy as we can - sometimes we've opted for a slightly increased data transfer (of results) to protect an individual's privacy.

## Existing directories of warm spaces

[Our directory of directories](https://open-innovations.github.io/warm-spaces/)

To add more directories, update the [data/data.yml](data/data.yml) file then run `perl build.pl` in the `data/` sub-directory.

## Data

The data comes from those directories that we were able to automatically collect and automatically parse. If there are mistakes, please refer back to the original source(s) and ask them to update those. If you have a warm space that isn't included, please refer to the directories of warm spaces and choose an appropriate source to register with. There will be duplicates in the results due to organisations registering with multiple directories. It is very hard to automatically remove duplicates because the titles and addresses can vary between databases; they depend on how individuals have happened to enter text. We've left duplicates in because humans can more easily work out that they are duplicates and sometimes useful/correct information may not be in each entry.

## Opening times

Please note that **our display of opening times may not always be correct**. This is because the original data sources have allowed people to provide opening hours as unstructured free-text. There are hundreds of ways that organisations have chosen to write their opening hours and some choices of formatting make it very [hard for our code to work it out correctly](https://github.com/open-innovations/warm-spaces/actions/runs/3637587054/jobs/6138765472#step:4:6). The indications of opening given in this tool are therefore our automated best attempt to work them out. We're doing pretty well at it but have also provided a view of the original text for each. You can also check against the original sources. We suggest that people/organisations/directories use [an existing standard format for opening times](https://wiki.openstreetmap.org/wiki/Key:opening_hours) such as the one developed by Open Street Map when adding data to the various directories. That way it will be easier to check for certain kinds of data entry mistake.
			
## Location & privacy

For the best results, the "near my location" button should work best. That uses your device's location (if you let it). We could have just sent that to our server to find the nearest warm spaces to your location but we decided to do as much as we can to respect your privacy whilst still being useful. If you do allow your location to be used, it is rounded to the nearest ~5km×2.5km grid cell and then all the warm spaces for that cell (and some neighbouring ones just in case you are on the edge of a grid cell) are loaded. This rounding ensures that your exact location doesn't leave this page so we (or our server) won't get to know what it is. Once the results are sent back to this page, your precise location is then used (in the page) to order the results.

Some people, understandably, turn location services off on their device or block their browser from having access to that. In that case the "near my location" button obviously can't function. So we've also added a place search. Again, we could have taken the easy approach of sending what you type off to our server (or someone else's) to work out where that place is. But, instead, we've taken open data published by Ordnance Survey about place names, and then grouped those by first letter. So when you start typing, all our server needs to know is the first letter. This means a larger data usage than just passing full place name you've entered and returning a location, but felt reasonable to protect your privacy.

If you use the place name search then the distance we show on the search results will be from the Ordnance Survey centre of the place to the warm space. So, if you've searched for a large place like "Leeds" the distances and ordering will probably not be correct for you. We've included cities, towns, suburban areas, villages, and hamlets from the Ordnance Survey data so hopefully there is something close enough to you to be useful.
			
## Credits

This tool was created by Stuart Lowe, [Open Innovations](https://open-innovations.org/).

The results come from various directories of warm spaces; each result links back to the specific source directory that it came from. The original data has been contributed by individuals/organisations to those directories.

The place name search uses a subset of processed data from [Ordnance Survey's Open Names](https://www.ordnancesurvey.co.uk/business-government/products/open-map-names) released under the [Open Government Licence](http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) and is © Crown copyright and database right 2021 / Royal Mail data © Royal Mail copyright and database right 2021 / National Statistics data © Crown copyright and database right 2021.
