# IMD visualisation

This uses data from:

* [UK composite IMD from MySociety](https://pages.mysociety.org/composite_uk_imd/datasets/uk_index/latest) (see [notes](https://github.com/mysociety/composite_uk_imd))
* [Westminster Parliamentary Constitunecies 2021](https://geoportal.statistics.gov.uk/datasets/ons::westminster-parliamentary-constituencies-dec-2021-uk-bgc/explore)

Each geolocated warm space is assigned to a Parliamentary constituency. The constituencies are then ranked by their `pcon-deprivation-score` and grouped into deciles by constituency and each constituency coloured by the total number of warm spaces.
