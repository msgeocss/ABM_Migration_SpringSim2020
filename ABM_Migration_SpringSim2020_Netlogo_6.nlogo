; Amira Al-Khulaidy and Melanie Swartz
; Model of Movements for Migration
; Computational Social Science
; George Mason University
; Created using Netlogo 6.1.1, 2020

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; GLOBAL VARIABLES AND AGENT PROPERTIES
extensions [gis csv]; gis and csv extension for Netlogo
globals [countries mex_districts border_line border_pts bbox patch-scale scale-bar global-willingness global-means global-risk current-display num-crossed]
patches-own [water-here land-here border-here country district-name habitable? crossable? pop-count migrant-count
  border-sector-name border-wall-here border-crossing-point-here border-crossing-point-name border-crossing-point-name-abbr
  border-wall-here-status border-crossing-point-here-status
  border-crossed-here-count border-apprehended-here-count border-staying-here-count
  border-crossed-here ; people have crossed here may or may not be point of entry
]

breed [scale-bar-labels scale-bar-label]
scale-bar-labels-own [label-display]

breed [country-labels country-label]
country-labels-own [country-name-label pop-15 rep-pop-15]

breed [district-labels district-label]
district-labels-own [district-name-label pop-2015 rep-pop-2015 country-name]

breed [crossing-points crossing-point]
crossing-points-own [crossing-name crossing-sector crossing-abbr
  crossing-people-here-now crossing-crossed-here crossing-waiting-here crossing-processed-here crossing-apprehended-here crossing-returned-here]

breed [people person]
people-own [my-willingness-to-migrate my-migration-means my-risk-aversion-to-migrate my-home-country my-home-district my-home-patch my-hometown my-hometown-migrants
  migrating? migrating-time migration-status migration-status-time migration-status-history
   my-closest-border-crossing-point-name my-closest-border-crossing-point-name-abbr
  my-goal-border-crossing my-goal-border-crossing-label goal-changed? goal-history
  crossing-attempts crossing-attempts-history
  border-sector-crossed-at border-crossed-at-label border-crossed-at crossed-border?
  count-people-from-my-hometown-migrating count-people-near-me-migrating count-people-from-my-hometown-that-crossed count-people-from-my-district-that-crossed count-people-from-my-country-that-crossed
  my-closest-border-crossing-point my-random-border-crossing-goal my-social-crossing-goal my-current-geo-crossing-goal
  my-social-goal-source my-current-geo-crossing-source
  my-current-border-goal my-current-border-goal-source my-current-border-goal-abbr
  failed?
  time-to-leave
  ]


;; BUTTON PROCEDURE TO LOAD THE GIS DATA OF COUNTRIES ETC
to model-setup
  clear-all
  ;; GIS DATA LAYERS
  gis:load-coordinate-system (word "data/Countries_WGS84.prj"); projection file
  set countries gis:load-dataset "data/Countries_WGS84.shp"; country polygons
  set mex_districts gis:load-dataset "data/MX_districts.shp" ; Mexico districts
  set border_line gis:load-dataset "data/Mexico_and_US_Border.shp" ; black border line
  set border_pts gis:load-dataset "data/pts_border.shp"; actual ports of entry
  set patch-scale gis:load-dataset "data/25sqkm_box.shp"; includes a 25sq km square and a 50km square for determinging patch size
  set scale-bar gis:load-dataset "data/scale_200km.shp"; scale bar with 0, 100, 200km labels, and 2 boxes of 50km, and 2 of 100km use 50km for black, 100 for white
  set bbox gis:load-dataset "data/bbox.shp";
  ;; Draw the map
  draw
  reset-ticks
  set num-crossed 0
end

;; UPDATE THE MAP DISPLAY WITH COUNTRIES, WATER, AND BORDER CROSSINGS
to draw
  clear-drawing
  gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of bbox))

  gis:apply-coverage countries "CNTRY_NAME"  country
  gis:apply-coverage mex_districts "MX_NAME"  district-name
  ; remove the district label on the remote island so people don't go there
  ask patch -37 -19 [set district-name ""]
  gis:apply-coverage border_pts "SECTOR"  border-sector-name

  ; color the countries gray, water light blue
  ask patches
      [ifelse is-number? country = True ; GIS country will be NaN for water
        [set country "" ; handle NaN
          set water-here 1 set pcolor sky + 3 ]; if is number then water
        [set land-here 1 set pcolor gray + 3]
       if is-number? district-name = True
            [set district-name ""] ; handle NaN
       ]

  ; draw the Mexico state borders
  gis:set-drawing-color gray + 1
  ;gis:draw us_states 1
  gis:draw mex_districts 1

  ; draw the MX state borders
  gis:set-drawing-color gray - 1
  gis:draw countries 1.5

  ; draw the intl border line
  ask patches with [gis:intersects? border_line self]
    [set border-here 1] ; this is duplicate, but I am keeping it in the code for now]
  gis:set-drawing-color black + 3
  gis:draw border_line 7

  ; draw the border crossings
  ask patches
    [if gis:intersects? border_pts self ; setting crossing_here and adding the map to be coverted to
      [set border-crossing-point-here 1]
     ]
  create-US-MX-border-crossing-points

  ; for determining scale
  ;;gis:draw scale 1 ; 25sq km box to use to edit size of map display so a patch is about same size as this box in the center of MX
  ;;gis:draw bbox 1 ; overall map area

  draw-scale-bar

  ; lables for countries and mexico districts
  label-countries
  label-MX-states
end

;; CODE TO MAKE THE SCALE BAR IN THE LOWER LEFT
to draw-scale-bar
 ; make scale-bar

 ; scale bar was made with polygons in gis
  ; show 100 and 300 section as black, 200 as white
  gis:set-drawing-color black
  foreach  (gis:find-features scale-bar "VAL" "100")
     [ the-poly -> gis:fill the-poly  1 ]
  foreach  (gis:find-features scale-bar "VAL" "300")
     [ the-poly -> gis:fill the-poly  1 ]
  gis:set-drawing-color white
  foreach  (gis:find-features scale-bar "VAL" "200")
     [ the-poly -> gis:fill the-poly  1 ]

  ask patch -60 -38
      [sprout-scale-bar-labels 1
            [set size 0
             set label-color black
             set label "scale"
             ]
        ]

  ask patch -64 -42
      [sprout-scale-bar-labels 1
            [set size 0
             set label-color black
             set label "0"
             set ycor -42.5
             ]
        ]
   ask patch -48 -42
      [sprout-scale-bar-labels 1
            [set size 0
             set label-color black
             set label "300 km"
             set ycor -42.5
              ]
        ]
end

;; CREATE AND DISPLAY LABEL COUNTRY NAMES AT CENTER OF POLYGON FOR COUNTRY
to label-countries
foreach gis:feature-list-of countries [ [vector-feature] ->
      let centroid gis:location-of gis:centroid-of vector-feature
      ; centroid will be an empty list if it lies outside the bounds
      ; of the current NetLogo world, as defined by our current GIS
      ; coordinate transformation
      if not empty? centroid
      [ create-country-labels 1
        [ set xcor item 0 centroid + 2
          set ycor item 1 centroid
          set size 0
          set country-name-label gis:property-value vector-feature "CNTRY_NAME"
          set label-color gray - 2
          set label country-name-label
          set pop-15 gis:property-value vector-feature "POP15"
       ]]]

  ; minor fixes for label placement to improve appearance
  ask patch 8 37 [ sprout-country-labels 1 ; handle the United States label so displays on map
        [ set size 0
          set country-name-label [country] of patch-here
          set label-color gray - 2
          set label country-name-label
          ;set pop-2015 gis:property-value vector-feature "POP_2015"
       ]]
  ask country-labels with [ country-name-label = "Guatemala"]
      [set xcor xcor + 3.5
       set ycor ycor - 2]
  ask country-labels with [ country-name-label = "El Salvador"]
      [set ycor ycor - 1.5]
  ask country-labels with [ country-name-label = "Belize"]
      [set xcor xcor + 4
       set ycor ycor - 1.5]
end


;; CREATE AND DISPLAY LABELS FOR MEXICO DISTRICTS
to label-MX-states
foreach gis:feature-list-of mex_districts [ [vector-feature] ->
      let centroid gis:location-of gis:centroid-of vector-feature
      ; centroid will be an empty list if it lies outside the bounds
      ; of the current NetLogo world, as defined by our current GIS
      ; coordinate transformation
      if not empty? centroid
      [ create-district-labels 1
        [ set xcor item 0 centroid
          set ycor item 1 centroid
          set size 0
          set district-name-label gis:property-value vector-feature "MX_NAME"
          set pop-2015 gis:property-value vector-feature "POP_2015"
      ]]]

end


;; CREATE AND DISPLAY LABEL BORDER CROSSINGS POINTS BETWEEN US AND MEXICO
to create-US-MX-border-crossing-points
  foreach gis:feature-list-of border_pts [ [vector-feature] ->
    gis:set-drawing-color orange + 2
    gis:draw border_pts 7
     ; a feature in a point dataset may have multiple points, so we
      ; have a list of lists of points, which is why we need to use
      ; first twice here
      let location gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
      ; location will be an empty list if the point lies outside the
      ; bounds of the current NetLogo world, as defined by our current
      ; coordinate transformation
      if not empty? location
      [ create-crossing-points 1 ;hatch-border-crossing-points 1
        [ set xcor item 0 location
          set ycor item 1 location
          set shape "circle"
          set color orange + 2
          set size 2
          set crossing-sector gis:property-value vector-feature "SECTOR"
          set crossing-name crossing-sector
          set crossing-abbr gis:property-value vector-feature "ABBR"
          set label-color black
          set label crossing-abbr
          set crossing-people-here-now 0
          set crossing-crossed-here 0
          set crossing-waiting-here 0
          set crossing-processed-here 0
          set crossing-apprehended-here 0
          set crossing-returned-here 0
      ]]]

 ; create this one manually because otherwise it is on the same patch as another border crossing
  ask crossing-points with [crossing-abbr = "YM"]
    [set ycor ycor - 1]

  ;; ADD THE NAMES TO THE CROSSING POINTS AS MAIN PORTS OF ENTRY
  ask crossing-points
   [ask patch-here
     [set border-sector-name [crossing-sector] of myself
      set border-crossing-point-name [crossing-name] of myself
      set border-crossing-point-name-abbr [crossing-abbr] of myself
    ]]

end


;; BUTTON PROCEDURE TO CREATE POPULATION
to setup-population
  ask people [die]
  reset-ticks
  clear-all-plots
  ask patches with [land-here = 1] [set pcolor gray + 3]
  set global-willingness 0
  set global-means 0
  set global-risk 0

  if pop-display = "Mexico" ; just Mexico population
      [ask district-labels
         [set rep-pop-2015 round (pop-2015 / population-scale)
          hatch-people rep-pop-2015
          [assign-people-attributes]]
       ask people ; move to one of random patches in my district
           [set my-home-district item 0 [district-name-label] of district-labels-here
             move-to one-of patches with [district-name = [my-home-district] of myself]
            ]
       ]

  if pop-display = "all" ; all countries
     [ask country-labels
        [set rep-pop-15 round (pop-15 / population-scale)
         hatch-people rep-pop-15
          [assign-people-attributes]]
      ask people
          [move-to one-of patches with [country = [my-home-country] of myself]
          set my-home-district ""
          ]
        ask people with [my-home-country != "Mexico"][die] ;; just mexico
        ask people [set color green]
  ]

  ; update people attributes based on their location where they are intialized
  ask people
    [set my-home-district [district-name] of patch-here
     set my-home-patch patch-here
     set my-hometown patches in-radius 1
     set my-hometown-migrants (other people-on my-hometown) with [migration-status = "migrating"]
     set count-people-from-my-hometown-migrating count (other people-on my-hometown) with [migration-status = "migrating"]

      ; set closest point
     set my-closest-border-crossing-point min-one-of crossing-points [ distance myself ]

     if my-home-district = "Baja California Sur" or my-home-district = "Baja California"
            [let baja-points crossing-points with [crossing-abbr = "SD" or crossing-abbr =  "EC" or crossing-abbr = "YM"]
                set my-closest-border-crossing-point one-of baja-points]

     ; initialize their desires for border location and associated attributes
     set my-closest-border-crossing-point-name [crossing-name] of my-closest-border-crossing-point
     set my-closest-border-crossing-point-name-abbr [crossing-abbr] of my-closest-border-crossing-point

     set my-goal-border-crossing-label my-closest-border-crossing-point-name-abbr
     set my-goal-border-crossing  my-closest-border-crossing-point; agent of crossing point or a border patch intializes with closest crossing point, updates based on network or travel or restrictions

     set goal-history fput my-goal-border-crossing goal-history

     set my-random-border-crossing-goal one-of crossing-points

     set my-current-geo-crossing-goal ""
     set my-current-geo-crossing-source "none"

     set my-social-crossing-goal ""
     set my-social-goal-source "none"

     set my-current-border-goal ""
     set my-current-border-goal-abbr ""

     set count-people-near-me-migrating count (other people-on patch-here) with [migration-status = "migrating"]

     face my-goal-border-crossing
  ]



  ; get initial information from others agents in the model such as where they crossed or are headed
   ask people with [migration-status = "migrating" ]
    [update-info-from-people-from-hometown-that-crossed ;find out where others crossed
     update-info-from-people-migrating-near-me]; find out where others near me are going

  ; update my border goal based on movement style and possibly info from others
    ask people with [migration-status = "migrating" ]
    [ check-migration-goal
       face my-goal-border-crossing]

  ; update population density information of patches of the environment
  ask patches
    [set pop-count count people-here
     set migrant-count count people-here with [migrating? = True]
    ]

  update-display
end


;; HELPER FUNCTION TO CHECK FOR NEAREST BORDER CROSSING
to-report name-of-nearest-border-crossing
  if my-home-district != "Baja California Sur" or my-home-district != "Baja California"
   [let my-closest-border-crossing-patch min-one-of (patches with [border-crossing-point-here = 1 ]) [ distance myself ]; initializing with closest border patch
    report [border-crossing-point-name] of my-closest-border-crossing-patch]


end


;; PEOPLE ATTRIBUTES INITIALIZATION
to assign-people-attributes
   ;set shape "person"
   set my-home-country [country] of patch-here;one-of country-labels-here
   set my-willingness-to-migrate random-normal avg-willingness-to-migrate 3; 0-100
   set my-migration-means  random-normal avg-means 3 ; 0-100
   set my-risk-aversion-to-migrate random-normal avg-risk-aversion 3; 0-100
   set migrating? False
   set migrating-time 0
   set migration-status "not" ; not, stay, migrating, at_border, processing, apprehended, crossed, returning
   set migration-status-time 0
   set migration-status-history []
   set my-closest-border-crossing-point-name ""; updated by model
   set my-goal-border-crossing "" ; agent of border-crossing-point, patch
   set my-goal-border-crossing-label "" ; none, point of entry name, wall, fence, open border patch
   set border-sector-crossed-at "" ; name of most recent sector crossed at
   set border-crossed-at-label "" ; none, point of entry name, wall, fence, open patch
   set border-crossed-at "" ;  agent of border-crossing-point, patch
   set crossing-attempts-history [] ; adds patch id and if apprehended or crossed
   set crossing-attempts 0
   set crossed-border? False
   set label ""
   set size 0
   set goal-history []
   set my-social-crossing-goal ""
   set my-current-border-goal ""
   set my-current-border-goal-source "none"
   set my-current-border-goal-abbr ""
   set count-people-from-my-hometown-that-crossed 0
   set count-people-from-my-district-that-crossed 0
   set count-people-from-my-country-that-crossed 0
   set time-to-leave random 50

  check-my-migration-status
end


;; BUTTON PROCEDURE TO RUN THE MODEL
to run-model
  ; Stop the model when no more people migrating
  if not any? people with [migration-status = "migrating"]
      [stop]

  ; have agents get info from other agents that are close by or those from their hometown that already crossed
   ask people with [migration-status = "migrating" ]
    [update-info-from-people-from-hometown-that-crossed ;find out where others crossed
     update-info-from-people-migrating-near-me]; find out where others near me are going

  ; migration movement
    ask people with [migration-status = "migrating" and ticks > time-to-leave]
      [
        check-migration-goal
        face my-current-border-goal
        help-orient ; helps those agents stuck in central america or yucatan navigate the lower part of Mexico


        ; add a little stochasticity in movement
         lt 30
         rt random-normal 30 2
         fd .4
        avoid-water
        ]


  ; update pop density each tick
  ask patches
    [set pop-count count people-here
     set migrant-count count people-here with [migrating? = True]
     ]

  ; enable border crossings and apprehensions etc
  handle-people-at-border

  set num-crossed count people with [migration-status = "crossed"]
  update-globals
  update-display

  tick
end


;; ROUTINE TO UPDATE WILLINGNESS TO MIGRATE
to update-my-migration-variables
  ; update willingness to migrate based on sliders

  ;; if the sliders changed then trend towards the middle of the difference
  if global-willingness != avg-willingness-to-migrate
    [set my-willingness-to-migrate  random-normal (round (abs (avg-willingness-to-migrate - my-willingness-to-migrate) / 2) +  my-willingness-to-migrate) 1.5]; 0-100

   if global-means != avg-means
      [set my-migration-means  random-normal (round (abs (avg-means - my-migration-means) / 2) +  my-migration-means) 1.5] ; 0-100

  if global-risk != avg-risk-aversion
    [set my-risk-aversion-to-migrate  random-normal (round (abs (avg-risk-aversion - my-risk-aversion-to-migrate) / 2) +  my-risk-aversion-to-migrate) 1.5]; 0-100
end


;; ROUTINE TO GET INFO FROM PEOPLE FROM HOMETOWN THAT CROSSED
to update-info-from-people-from-hometown-that-crossed
  ; check where others from my hometown went, and pick the most common border crossing used
  if count-people-from-my-hometown-that-crossed = 0 and count-people-from-my-hometown-migrating > 0
     [set my-social-crossing-goal item 0 modes [my-current-border-goal] of my-hometown-migrants
        set my-social-goal-source "hometown-goal" ]

  ; check the status of those from hometown that crossed
  let people-from-my-hometown-that-crossed  my-hometown-migrants with [migration-status = "crossed"]

  set count-people-from-my-hometown-that-crossed count people-from-my-hometown-that-crossed
  if count-people-from-my-hometown-that-crossed > 0
       [set my-social-crossing-goal item 0 modes [border-crossed-at] of people-from-my-hometown-that-crossed
         set my-social-goal-source "hometown-crossed"  ]

  ; if not any from my hometown that crossed then ask those from the same district that crossed
   set count-people-from-my-district-that-crossed count people with [migration-status = "crossed"  and my-home-district != "" and my-home-district = [my-home-district] of myself]
   if count-people-from-my-hometown-that-crossed = 0 and count-people-from-my-district-that-crossed > 0
       [let people-from-my-district-that-crossed  people with [migration-status = "crossed"  and my-home-district = [my-home-district] of myself]
        set my-social-crossing-goal item 0 modes [border-crossed-at] of people-from-my-district-that-crossed
        ;set my-social-crossing-goal-label modes [border-crossed-at-label] of people-from-my-district-that-crossed with [border-crossed-at-label = my-social-crossing-goal]
        set my-social-goal-source "district"  ]

  ; if not any from my district that crossed then ask those from my country where they crossed
  set count-people-from-my-country-that-crossed count people with [migration-status = "crossed"  and my-home-district = "" and my-home-country = [my-home-country] of myself]
  ; only non mexico will use the country one
  if count-people-from-my-hometown-that-crossed = 0 and my-home-country != "Mexico" and count-people-from-my-country-that-crossed > 0
       [let people-from-my-country-that-crossed  people with [migration-status = "crossed"  and my-home-country = [my-home-country] of myself]
        set my-social-crossing-goal item 0 modes [border-crossed-at] of people-from-my-country-that-crossed
        ;set my-social-crossing-goal-label modes [border-crossed-at-label] of people-from-my-country-that-crossed with [border-crossed-at-label = my-social-crossing-goal]
        set my-social-goal-source "country"  ]
end

;; ROUTINE TO GET INFO FROM NEARBY AGENTS WHILE MIGRATING
to update-info-from-people-migrating-near-me
  ; if more than 2 people near me, find out where they are going
  let people-near-me-migrating other people-here with [migration-status = "migrating"]
  set count-people-near-me-migrating count people-near-me-migrating
  if count people-near-me-migrating > 2
    [set my-current-geo-crossing-goal item 0 modes [my-current-border-goal] of people-near-me-migrating
      set my-current-geo-crossing-source "caravan"]
end


;; GUI DROP DOWN CHOOSER TO ENABLE UPDATING DURING MODEL RUN
to check-migration-goal
      ;; Type of movement used to orient person migrating
      if border-choice = "border-nearest"
         [set my-current-border-goal my-closest-border-crossing-point
           set my-current-border-goal-source "nearest"]
      if border-choice = "border-random"
         [set my-current-border-goal my-random-border-crossing-goal
          set my-current-border-goal-source "random"]
      if border-choice = "border-caravan"
         [set my-current-border-goal my-current-geo-crossing-goal
          set my-current-border-goal-source my-current-geo-crossing-source]
      if border-choice = "border-network-hometown"
          [set my-current-border-goal my-social-crossing-goal
           set my-current-border-goal-source my-social-goal-source
           ]
      if my-current-border-goal  = ""
        [set my-current-border-goal my-closest-border-crossing-point
         set my-current-border-goal-source "none-nearest"]

     set my-current-border-goal-abbr [crossing-abbr] of my-current-border-goal
end



;; ROUTINE TO START OR STOP MIGRATING
to check-my-migration-status
  let migrate False
  ifelse (my-willingness-to-migrate > 50 and (my-risk-aversion-to-migrate < my-migration-means)); +  100 ))
      [set migrate True]
      [set migrate False]

   ifelse migrating? = migrate
    [set migration-status-time migration-status-time + 1 ] ; just add time
    ; change migrating to True or Flase
    [set migrating? migrate
     set migration-status-time 0]

   ; start migrating
  if (migration-status = "not" or migration-status = "stay") and migrating? = True
      [set migration-status "migrating" set size 2]

  ; stop migrating and stay
  if migrating? = False and migration-status = "migrating"
      [set migration-status "stay" set size 1]

  ; update migrating-status-history
 set migration-status-history fput migration-status migration-status-history
end



;; SUPPORT ROUTINES FOR MOVEMENT

; handle those in Yucatan and Central america to get around curves and narrow geography
to help-orient
  if xcor >= 20
   [
    if xcor > 40
      [face patch 40 -26]
    if xcor >= 30 and xcor < 40
      [face patch 30 -26]
    if xcor >= 20 and xcor < 30
      [face patch 20 -20]
  ]

  if (my-home-district = "Baja California Sur" or my-home-district = "Baja California") and ycor < 27
    [face patch -53 27]
end


to get-nearest-part-of-border ; doesn't have to be a port of entry it can be anywhere along the border
  face min-one-of patches with [border-here = 1] [distance self]
end



;; BORDER AND CROSSINGS UPDATE PEOPLE ATTRIBUTES AT BORDER
to handle-people-at-border
  ; update people who arrived at the border
  ask patches with [border-here = 1 and migrant-count > 0]
    [if any? people-here with [migration-status = "migrating"]
      [ask people-here with [migration-status = "migrating"]
         [set migration-status "at_border"
          set migration-status-time 0
    ]]]

  cross-border ; done by border crossing-points
end


;; ROUTINE TO HANDLE THOSE THAT ARE AT THE BORDER TO ENABLE CROSSING OR OTHER ACTION
to cross-border
  ;; update count of people at border, crossed, waiting
  ask crossing-points
   [
    ; count of people at border crossing waiting to cross
    if any? people-here with [migration-status = "at_border"]
        [set crossing-people-here-now count people-here with [migration-status = "at_border"]

        let this-many-to-cross crossing-people-here-now
        if border_restriction = True
            [set this-many-to-cross round (crossing-people-here-now / 2)]


        ; update attributes of people who crossed
        ask n-of this-many-to-cross people-here with  [migration-status = "at_border" ]
           [  set migration-status "crossed"
              set crossed-border? True
              ;set migrating? False
              set border-sector-crossed-at [border-sector-name] of patch-here
              set border-crossed-at-label [border-crossing-point-name-abbr] of patch-here
              set border-crossed-at myself

             set crossing-attempts crossing-attempts + 1
             set crossing-attempts-history fput myself crossing-attempts-history
            ]

           ; those not allowed to cross now decide to head for another border crossing point
        if any? people-here with [migration-status = "at_border"]
            [ask people-here with [migration-status = "at_border"]
               [
                set failed? True
                set migration-status  "migrating"
               ;update nearest and goal
                set my-closest-border-crossing-point min-one-of other crossing-points [ distance myself ]; initializing with closest border patch

                ;set my-current-border-goal my-closest-border-crossing-point
                rt 180 fd 5
                rt random 360 fd 2]
             ]

          ; Update counters of those that crossed
         let crossed-now  count people-here with [migration-status = "crossed"]
         set crossing-crossed-here   crossing-crossed-here + crossed-now
    ]]
end


; HELPER ROUTINE FOR THOSE THAT END UP IN WATER
to avoid-water
  ; face the nearest patch with no water and move towards it
  if any? people-on patches with [water-here = 1]
    [ask people-on patches with [water-here = 1]
      [
        let no-water one-of neighbors with [water-here = 0]
        face  min-one-of patches with  [water-here != 1]  [distance myself]
      fd 1]
     ]
end

; UPDATE GLOBAL VARIABLES
to update-globals
   ; set global values of params to check for updates
   set global-willingness avg-willingness-to-migrate
   set global-means avg-means
   set global-risk avg-risk-aversion
end

; UPDATE THE DISPLAY CHOICES FOR THE MAP
to update-display
if current-display != change-display ;; if change in display setting then update display
  [
   if change-display = "pop"
      [ask patches with [land-here = 1] [set pcolor gray + 3]
       ask people [set size 1.5]
       ]
  if change-display = "migrants only"
      [ask patches with [land-here = 1] [set pcolor gray + 3]
       ask people [set size 1.5]
       ask people with [migration-status = "not"] [set size 0]
       ]

  if change-display = "pop-dens"
     [ask people [set size 0]
      let max-pop max [pop-count] of patches
      ask patches with [land-here = 1 and country != "United States"]
        [ifelse pop-count > 0
           [set pcolor scale-color 22 pop-count  max-pop 1
              if pcolor >= 29 and pcolor < 30 [set pcolor pcolor - 1]; so color is not white
              if pcolor >= 20 and pcolor < 22 [set pcolor 22]; so color is not black
             ]
           [set pcolor gray + 3]
    ]]

  if change-display = "migrant-dens"
     [ask people [set size 0]
      let max-migrant max [migrant-count] of patches
      ask patches with [land-here = 1 and country != "United States"]
         [ifelse migrant-count > 0
           [set pcolor scale-color 73 migrant-count max-migrant 0
               if pcolor >= 79 and pcolor < 80 [set pcolor pcolor - 1]; so color is not white
               if pcolor >= 70 and pcolor < 72 [set pcolor 72]; so color is not black
            ]
           [set pcolor gray + 3]
    ]]

  if change-display = "pop-dens and migrants"
     [ask people [set size 1.5]
      ask people with [migration-status = "not"] [set size 0]
       let max-pop max [pop-count] of patches
       ask patches with [land-here = 1 and country != "United States"]
         [ifelse pop-count > 0
           [ set pcolor scale-color 22 pop-count max-pop 1
               if pcolor >= 29 and pcolor < 30 [set pcolor pcolor - 1]; so color is not white
               if pcolor >= 20 and pcolor < 22 [set pcolor 22]; so color is not black
            ]
           [set pcolor gray + 3]
    ]]
  if change-display = "pop-dens and migrant-dens"
     [ask people [set size 0]
      let max-pop max [pop-count] of patches
      let max-migrant max [migrant-count] of patches
       ask patches with [land-here = 1 and country != "United States"]
         [ifelse pop-count > 0
           [set pcolor scale-color 22 pop-count max-pop 1
             if pcolor >= 29 and pcolor < 30 [set pcolor pcolor - 1]; so color is not white
             if pcolor >= 20 and pcolor < 22 [set pcolor 22]; so color is not black
             if migrant-count > 0
                [set pcolor scale-color 73 migrant-count max-migrant 0
                 if pcolor >= 79 and pcolor < 80 [set pcolor pcolor - 1] ; so color is not white
                 if pcolor >= 70 and pcolor < 72 [set pcolor 72]; so color is not black
              ]
            ]
            [set pcolor gray + 3]
    ]]
  ]
end


;; END OF CODE
@#$#@#$#@
GRAPHICS-WINDOW
238
27
840
418
-1
-1
4.4
1
10
1
1
1
0
0
0
1
-67
67
-43
43
0
0
1
Days
30.0

BUTTON
56
30
182
63
1. model-setup
model-setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
240
10
549
44
Agent-Based Model of Migration Movement
13
0.0
1

BUTTON
38
116
193
149
2. setup-population
setup-population
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
847
195
944
240
Rio Grande (RG)
count people with [border-crossed-at-label = \"RG\"]
17
1
11

MONITOR
949
195
1023
240
Laredo (LR)
count people with [border-crossed-at-label = \"LR\"]
17
1
11

MONITOR
1027
195
1101
240
Del Rio (DR)
count people with [border-crossed-at-label = \"DR\"]
17
1
11

MONITOR
1105
194
1184
239
Big Bend (BB)
count people with [border-crossed-at-label = \"BB\"]
17
1
11

MONITOR
848
245
920
290
El Paso (EP)
count people with [border-crossed-at-label = \"EP\"]
17
1
11

MONITOR
925
245
1001
290
Tuscon (TS)
count people with [border-crossed-at-label = \"TS\"]
17
1
11

MONITOR
1003
245
1071
290
Yuma (YM)
count people with [border-crossed-at-label = \"YM\"]
17
1
11

MONITOR
1075
245
1160
290
El Centro (EC)
count people with [border-crossed-at-label = \"EC\"]
17
1
11

MONITOR
1164
244
1253
289
San Diego (SD)
count people with [border-crossed-at-label = \"SD\"]
17
1
11

PLOT
846
11
1191
188
Migrants crossed at port of entry
Days
% of all Migrants
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Rio Grande (RG)" 1.0 0 -11221820 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"RG\"] / num-crossed * 100] [plot 0]"
"Laredo (LR)" 1.0 0 -13493215 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"LR\"] / num-crossed * 100] [plot 0]"
"Del Rio (DR)" 1.0 0 -10649926 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"DR\"] / num-crossed * 100] [plot 0]"
"Big Bend (BB)" 1.0 0 -8630108 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"BB\"] / num-crossed * 100] [plot 0]"
"El Paso (EP)" 1.0 0 -14070903 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"EP\"] / num-crossed * 100] [plot 0]"
"Tuscon (TS)" 1.0 0 -2674135 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"TS\"] / num-crossed * 100] [plot 0]"
"Yuma (YM)" 1.0 0 -955883 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"YM\"] / num-crossed * 100] [plot 0]"
"El Centro (EC)" 1.0 0 -4757638 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"EC\"] / num-crossed * 100] [plot 0]"
"San Diego (SD)" 1.0 0 -15040220 true "" "ifelse num-crossed > 0 [plot count people with [border-crossed-at-label = \"SD\"] / num-crossed * 100] [plot 0]"

SWITCH
29
276
200
309
border_restriction
border_restriction
1
1
-1000

CHOOSER
12
228
231
273
border-choice
border-choice
"border-random" "border-nearest" "border-caravan" "border-network-hometown"
3

BUTTON
56
312
169
345
3. run-model
run-model
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
153
209
186
avg-willingness-to-migrate
avg-willingness-to-migrate
0
100
60.0
1
1
NIL
HORIZONTAL

MONITOR
1093
295
1174
340
population
count people ;* population-scale
17
1
11

MONITOR
1179
342
1263
387
num crossed
count people with [migration-status = \"crossed\"]
17
1
11

MONITOR
1094
341
1175
386
migrating
count people with [migration-status = \"migrating\"]
17
1
11

CHOOSER
104
66
211
111
population-scale
population-scale
50000 100000
1

CHOOSER
7
66
99
111
pop-display
pop-display
"Mexico" "all"
1

SLIDER
1
190
137
223
avg-risk-aversion
avg-risk-aversion
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
140
190
236
223
avg-means
avg-means
0
100
42.0
1
1
NIL
HORIZONTAL

MONITOR
1180
295
1261
340
at_border
count people with [migration-status = \"at_border\"]
17
1
11

PLOT
850
295
1089
415
Migration status
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"migrating" 1.0 0 -7500403 true "" "plot count people with [migration-status = \"migrating\"]"
"at_border" 1.0 0 -2674135 true "" "plot count people with [migration-status = \"at_border\"]"
"crossed" 1.0 0 -10899396 true "" "plot count people with [migration-status = \"crossed\"]"

CHOOSER
119
373
232
418
change-display
change-display
"pop" "migrants only" "pop-dens" "migrant-dens" "pop-dens and migrants" "pop-dens and migrant-dens"
0

TEXTBOX
18
375
123
417
You can change dispaly options while model runs.
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This is an agent-based model about migration from people using the southwestern United States-Mexico border to enter the United States. The model looks at the behavior and decision-making in regard to how they travel to the border, and how group dynamics and the influence of other people can play a role in the trajectory under different U.S. border-policy scenarios.

## HOW IT WORKS

The agents are generated on the landscape proportional to the size of the population in the Mexican districts and Central American countries. Each agent is endowed with willingness-to-migrate, risk-aversion, and means-to-migrate attributes, which is user defined via sliders on the model interface. The model enables the user to explore how different decision-making and communication processes are used by the agents to decide on which U.S. border port of entry the agent will choose. In addition, the user can impose effects of border restrictions to limit the capacity of the number of migrants that are allowed to cross the border at the ports of entry.

To set up the model, press the first button "1. model-setup" to create the environment and load the base map layers for land, water, and the borders. After the model map display has been loaded, the user can adjust the initial parameters for agent’s willingness-to-migrate, risk-aversion, and means-to-migrate which is used during the population creation. The population of agents will be created by pressing the second button "2. setup-population". The number of agents on the display will be proportional to the population sizes for each Mexican district based on the 2015 Mexico census population estimates and based on the latest population size estimates for the Central American countries. The agents are initialized at random locations within their district if they are in Mexico. Otherwise they are initialized in their country.

To run the model, the "3. run-model" button will run the model which starts by agents considering whether or not to migrate based on their willingness-to-migrate, risk-aversion, and means-to-migrate. The agents who choose to migrate will then pick a U.S. border port of entry based on the current border-choice drop-down selection the user of the model specifies. The migrants will then travel towards their chosen border crossing goal and each model iteration (tick) of one day the agent will reassess their goal based on the nearest crossing or information from other agents if the border-choice is for caravan or network-hometown.
Once the agents arrive at the border, the impact of the border-restriction setting from the model interface will impact what percent of migrants are allowed to cross the border each day as capacity. If migrants are unsuccessful at crossing when they arrive at the border, they randomly choose whether to wait or to choose another segment of the border or port of entry.

Border-choice: While each agent is initialized with the nearest port of entry, as soon as the model starts running the agents will update their desired border crossing point based on the user specified option for border-choice on the model GUI. 

The border-choice drop down enables the agents to update their desired border crossing location each iteration (which represents a day) based on the following:

- border-random: each agent randomly chooses a port of entry and heads towards it.
- border-nearest: each agent picks the nearest port of entry to their current location.
- border-caravan: each agent updates their desired port of entry to be the most common - border crossing goal location shared by the nearby (Moore neighborhood) migrating agents when there are 3 or more within the vicinity.
- border-network-hometown: each agent updates their desired port-of-entry based on the most common border crossing location that was successfully crossed by other agents from the same originating neighborhood (hometown). When there are no other agents within the hometown, then the district is used, and for Central American countries only the country level is considered. 

Border-restriction: The user of the model can toggle on or off border restrictions while the model is running to examine the impacts. Border restriction on only enables a 50-50 chance of the migrant at the port of entry to be allowed to cross that day.


## THINGS TO NOTICE

While the mode and speed of travel in reality will vary greatly per migrant, the model assumes that migrants travel approximately 30km a day, which was based on reporting from 2018. Thus, each model iteration (tick) represents one day and the size of each patch is approximately 30km.

Our research found that the user selected border-choice option for  border-network-hometown yielded volume of migrants across the ports of entry to be the most similar to the actual volumes reported by the U.S. Customs and Border Patrol numbers for the years 2015-2018. This indicates that when modeling migration movements and patterns, it is important to represent the social network used by agents rather than just random or directed movement such as choosing the nearest border (which would be also similar to a gravity model).


## THINGS TO TRY

The average willingness to migrate, risk, and means need to be adjusted before creating the population. Note that only agents that are able to migrate will be displayed as green triangles. It may appear that there are no agents if the conditions are set in such a way as the willingness to migrate is too high, risk-aversion is too high, and means to migrate is too low.

The user can change the decision-making and communication processes among the agents by changing the border-choice even while the model is running. This may change the direction some of the migrants are traveling as they adjust to a different port of entry. 

The user can change the display to show the agents moving as green triangles pointing in the direction they are headed or to represent the population density of the agents as they move as tan colored patches with darker tan representing higher population density. Changing the population-display to Mexico will show the color of each agent based on their district.

When the model is open, the model setup only needs to be run once by pressing the button "1. model-setup". Because loading GIS data into the model can take some time, we set up the model so that the GIS data only needs to be loaded once and subsequent model runs can just remove the population and clear plots and still run again. Thus, for any subsequent runs of the model can be done by just pressing "2. setup-population" and then running the model again by adjusting any sliders or options desired, and then pressing "3. run-model". The speed of which the model runs can be adjusted by a slider on the Netlogo interface. The model can be started and stopped by pressing the "3. run-model". The model will automatically stop when there are no more agents left to migrate.


## EXTENDING THE MODEL

The model could be expanded to support road following and also to incorporate other travel challenges related to topography and could also add location of cities as population centers to create agents or to allow stop overs or destinations.

Currently the focus of this model is on crossing at the main ports of entry. There are other locations where crossings occur legally and illegally along the border that could also be incorporated. In addition, capacity per each port-of-entry could be adjusted.

The model could also be extended to include policing on both sides of the border, Mexican migration policies, and other external data that could be weighed by the agents such as socio-economic data and political climate.  

## CREDITS AND REFERENCES

This model was developed in 2019 and published in 2020 as part of the research presented at the SpringSim 2020 conference and published in the conference proceedings:
Al-Khulaidy, Amira and Swartz, Melanie (2020). Along the Border: An Agent-based Model of Migration Along the United States-Mexico Border.

The code and associated GIS map data files associated with this model is located on github at:
https://github.com/msgeocss/ABM_Migration_SpringSim2020/
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

eyeball
false
0
Circle -1 true false 22 20 248
Circle -7500403 true true 83 81 122
Circle -16777216 true false 122 120 44

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="max-cohere-turn">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-separate-turn">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum-separation">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-align-turn">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
