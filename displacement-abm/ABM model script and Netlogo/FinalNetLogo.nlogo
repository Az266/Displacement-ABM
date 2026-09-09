extensions [csv]

patches-own [
  elevation       ; Elevation in meters
  rainfall        ; Rainfall in mm
  water?          ; True if patch is water
  flood-risk?     ; True if elevation < 20
  river?          ; True if water? (for logic later)
  house?          ; Used for buildings
  shelter?        ; Used for shelters
  road?           ; Used for roads
  wealth          ; Wealth of the household (patch)
  displaced?      ; True if the household is displaced
  times-flooded   ; How many times the household has been flooded
  shelter-weeks   ; Number of weeks spent in shelter
  home-patch      ; Reference to the home patch for reintegration
]

globals [
  data-loaded?    ; Flag to track if data is successfully loaded
  flood-intensity ; Intensity of the flood (e.g., percentage)
  aid-amount      ; The amount of aid a displaced household receives
  aid-delay       ; The number of ticks until aid is given after displacement
  flood-tick-count ; Track the flood spread over time
   average-wealth  ; Average wealth of households
  reintegration-time ; Average time from displacement to home after flood
  percentage-flooded ; Percentage coverage of land flooded
  percentage-displaced ; Percentage of people displaced
]

to setup
  clear-all
  set data-loaded? false
  set flood-intensity slider-flood-intensity
  set aid-amount slider-aid-amount
  set aid-delay slider-aid-delay
  load-terrain-data "abm_base_grid_clean.csv"  ; Load terrain data

  if data-loaded? [
    recolor-terrain-custom  ; Updated to new name
    load-building-coordinates "osm_buildings.csv"  ; Load buildings
    recolor-buildings    ; Color buildings brown
    load-road-coordinates "osm_roads.csv" ; Load roads
    recolor-roads         ; Color roads grey
    load-shelter-coordinates "osm_shelters.csv" ; Load shelters
    recolor-shelters      ; Color shelters red
    setup-flood-intensity-plot  ; Initialize flood intensity plot
    setup-aid-distribution-plot  ; Initialize aid distribution plot
    setup-wealth-distribution-plot  ; Initialize wealth distribution plot
    setup-reintegration-plot  ; Initialize reintegration time plot
    setup-percentage-flooded-plot  ; Initialize percentage flooded plot
    setup-percentage-displaced-plot  ; Initialize percentage displaced plot
    setup-average-wealth-plot  ; Initialize average wealth plot
    reset-ticks
    print "✅ Terrain, buildings, roads, shelters, and plots setup complete!"
  ]
end

to go
  if not data-loaded? [
    user-message "Please load the terrain data first."  ; Make sure the data is loaded
    stop
  ]

  ; Simulate a flood event
  flood-simulation

  ; Check for displacement
  ask turtles [
    check-displacement
  ]

  ; Distribute aid to displaced households
  ask turtles [
    receive-aid
  ]

  ; Update plots with the current data
  update-flood-intensity-plot  ; Update flood intensity plot
  update-aid-distribution-plot  ; Update aid distribution plot
  update-wealth-distribution-plot  ; Update wealth distribution plot
  update-reintegration-plot  ; Update reintegration time plot
  update-percentage-flooded-plot  ; Update percentage flooded plot
  update-percentage-displaced-plot  ; Update percentage displaced plot
  update-average-wealth-plot  ; Update average wealth plot

  tick  ; Move the simulation forward by one tick
end

; === LOAD TERRAIN DATA FROM CSV FILE ===
to load-terrain-data [file-path]
  file-open file-path
  let header file-read-line ; skip header

  while [not file-at-end?] [
    let line file-read-line
    let row sublist (csv:from-row line) 0 5 ; lat, lon, elev, rain, is_water

    let lat item 0 row
    let lon item 1 row
    let elev item 2 row
    let rain item 3 row
    let water-flag item 4 row

    ; === Your dataset bounds
    let min-lat 25.059004791682653
    let max-lat 25.12270810530306
    let min-lon 91.94666343767092
    let max-lon 92.01700436892712

    let grid-width (max-pxcor - min-pxcor)
    let grid-height (max-pycor - min-pycor)

    let px min-pxcor + ((lon - min-lon) / (max-lon - min-lon)) * grid-width
    let py min-pycor + ((lat - min-lat) / (max-lat - min-lat)) * grid-height

    set px round px
    set py round py

    if patch px py != nobody [
      ask patch px py [
        set elevation elev
        set rainfall rain
        set water? (member? (word water-flag) ["true" "1" "True" "TRUE"])
        set river? water?
        set flood-risk? (elevation < 20)
        set house? false
        set shelter? false
        set road? false  ; Default to no road
        set wealth random 20000 + 5000  ; Random wealth between 5000 and 25000
        set times-flooded 0
        set displaced? false
        set shelter-weeks 0
        set home-patch nobody
      ]
    ]
  ]

  file-close
  set data-loaded? true
  print "✅ Loaded abm_base_grid_clean.csv"
end

; === LOAD BUILDING COORDINATES FROM CSV ===
to load-building-coordinates [file-path]
  file-open file-path
  let header file-read-line ; skip header

  while [not file-at-end?] [
    let line csv:from-row file-read-line
    let lat item 0 line  ; Get latitude from the line
    let lon item 1 line  ; Get longitude from the line

    ; Convert lat and lon to strings explicitly
    let lat-str (word lat)
    let lon-str (word lon)

    ; Now use these strings to convert to patches
    let p latlon-to-patch lat-str lon-str
    if p != nobody [
      ask p [ set house? true ]
    ]
  ]
  file-close
end

; === LOAD ROAD COORDINATES FROM CSV ===
to load-road-coordinates [file-path]
  file-open file-path
  let header file-read-line ; skip header

  while [not file-at-end?] [
    let line csv:from-row file-read-line
    let lat item 0 line  ; Get latitude from the line
    let lon item 1 line  ; Get longitude from the line

    ; Convert lat and lon to strings explicitly
    let lat-str (word lat)
    let lon-str (word lon)

    ; Now use these strings to convert to patches
    let p latlon-to-patch lat-str lon-str
    if p != nobody [
      ask p [ set road? true ] ; Set road flag to true
    ]
  ]
  file-close
end

; === LOAD SHELTER COORDINATES FROM CSV ===
to load-shelter-coordinates [file-path]
  file-open file-path
  let header file-read-line ; skip header

  while [not file-at-end?] [
    let line csv:from-row file-read-line
    let lat item 0 line  ; Get latitude from the line
    let lon item 1 line  ; Get longitude from the line

    ; Convert lat and lon to strings explicitly
    let lat-str (word lat)
    let lon-str (word lon)

    ; Now use these strings to convert to patches
    let p latlon-to-patch lat-str lon-str
    if p != nobody [
      ask p [ set shelter? true ] ; Set shelter flag to true
    ]
  ]
  file-close
end

; === CONVERT LAT/LON TO PATCH COORDINATES ===
to-report latlon-to-patch [lat lon]
  let min-lat 25.059004791682653
  let max-lat 25.12270810530306
  let min-lon 91.94666343767092
  let max-lon 92.01700436892712

  ; Convert lat/lon to numeric values using read-from-string
  let lat-num read-from-string lat
  let lon-num read-from-string lon

  let grid-width (max-pxcor - min-pxcor)
  let grid-height (max-pycor - min-pycor)

  let px round (min-pxcor + ((lon-num - min-lon) / (max-lon - min-lon)) * grid-width)
  let py round (min-pycor + ((lat-num - min-lat) / (max-lat - min-lat)) * grid-height)

  report patch px py
end

; === VISUALIZE TERRAIN ===
to recolor-terrain-custom
  ask patches [
    if is-boolean? water? and water? [
      set pcolor cyan  ; Water areas are cyan
    ]
    if is-boolean? water? and not water? [
      set pcolor green  ; Safe land is green
    ]
  ]
end

; === VISUALIZE BUILDINGS ===
to recolor-buildings
  ask patches with [house?] [
    set pcolor brown  ; Brown color for buildings
  ]
end

; === VISUALIZE ROADS ===
to recolor-roads
  ask patches with [road?] [
    set pcolor grey  ; Grey color for roads
  ]
end

; === VISUALIZE SHELTERS ===
to recolor-shelters
  ask patches with [shelter?] [
    set pcolor red  ; Red color for shelters
  ]
end

; === FLOOD SIMULATION ===
to flood-simulation
  set flood-intensity slider-flood-intensity  ; Get the flood intensity from the slider

  ; Gradual flooding logic (increase the flood coverage over time)
  set flood-tick-count flood-tick-count + 1  ; Increment the flood tick count

  if flood-tick-count < 10 [
    ; First 10 ticks: Flood only 10% of flood-risk patches
    let flood-amount (flood-intensity * 0.1)
    ask patches with [flood-risk?] [
      if random 100 < flood-amount [
        set pcolor blue  ; Flood the patch gradually
      ]
    ]
  ]
  if flood-tick-count >= 10 and flood-tick-count < 20 [
    ; Next 10 ticks: Flood 20% of flood-risk patches
    let flood-amount (flood-intensity * 0.2)
    ask patches with [flood-risk?] [
      if random 100 < flood-amount [
        set pcolor blue  ; Flood the patch gradually
      ]
    ]
  ]
  if flood-tick-count >= 20 and flood-tick-count < 30 [
    ; Next 10 ticks: Flood 30% of flood-risk patches
    let flood-amount (flood-intensity * 0.3)
    ask patches with [flood-risk?] [
      if random 100 < flood-amount [
        set pcolor blue  ; Flood the patch gradually
      ]
    ]
  ]
  if flood-tick-count >= 30 [
    ; After 30 ticks, flood all flood-risk patches (100%)
    ask patches with [flood-risk?] [
      set pcolor blue  ; Flood the patch fully
    ]
  ]

  print (word "Flood event: " flood-intensity "% wealth loss")
end

; === DISPLACEMENT LOGIC ===
to check-displacement
  if (wealth < 5000 and times-flooded >= 2) or (times-flooded >= 2) [
    if not displaced? [
      set displaced? true
      move-to-shelter
    ]
  ]
end

; === MOVE TO SHELTER ===
to move-to-shelter
  let available-shelters patches with [shelter? and not water?]
  if any? available-shelters [
    let shelter one-of available-shelters
    move-to shelter
    set home-patch patch-here
    set shelter-weeks 0  ; Reset shelter duration
  ]
end

; === AID DISTRIBUTION ===
to receive-aid
  if shelter-weeks >= aid-delay [
    set wealth wealth + aid-amount
    set displaced? false  ; Household is no longer displaced after receiving aid
    set shelter-weeks 0  ; Reset shelter duration
  ]
  set shelter-weeks shelter-weeks + 1  ; Increment shelter duration
end
; === PLOT SETUP ===

; Initialize the flood intensity plot
to setup-flood-intensity-plot
  set-current-plot "Flood Intensity"
  set-plot-x-range 0 100
  set-plot-y-range 0 100
  clear-plot
end

; Initialize the aid distribution plot
to setup-aid-distribution-plot
  set-current-plot "Aid Distribution"
  set-plot-x-range 0 100
  set-plot-y-range 0 100
  clear-plot
end

; Initialize the wealth distribution plot
to setup-wealth-distribution-plot
  set-current-plot "Wealth Distribution"
  set-plot-x-range 0 100
  set-plot-y-range 0 50000
  clear-plot
end

; Initialize the reintegration time plot
to setup-reintegration-plot
  set-current-plot "Reintegration Time"
  set-plot-x-range 0 100
  set-plot-y-range 0 100
  clear-plot
end

; Initialize the percentage flooded plot
to setup-percentage-flooded-plot
  set-current-plot "Percentage Flooded"
  set-plot-x-range 0 100
  set-plot-y-range 0 100
  clear-plot
end

; Initialize the percentage displaced plot
to setup-percentage-displaced-plot
  set-current-plot "Percentage Displaced"
  set-plot-x-range 0 100
  set-plot-y-range 0 100
  clear-plot
end

; Initialize the average wealth plot
to setup-average-wealth-plot
  set-current-plot "Average Wealth"
  set-plot-x-range 0 100
  set-plot-y-range 0 50000
  clear-plot
end

; === PLOT UPDATES ===

; Update flood intensity plot
to update-flood-intensity-plot
  set-current-plot "Flood Intensity"
  plot flood-intensity
end

; Update aid distribution plot
to update-aid-distribution-plot
  set-current-plot "Aid Distribution"
  plot aid-amount
end

; Update wealth distribution plot
to update-wealth-distribution-plot
  set-current-plot "Wealth Distribution"
  plot average-wealth
end

; Update reintegration time plot
to update-reintegration-plot
  set-current-plot "Reintegration Time"
  plot reintegration-time
end

; Update percentage flooded plot
to update-percentage-flooded-plot
  set-current-plot "Percentage Flooded"
  plot percentage-flooded
end

; Update percentage displaced plot
to update-percentage-displaced-plot
  set-current-plot "Percentage Displaced"
  plot percentage-displaced
end

; Update average wealth plot
to update-average-wealth-plot
  set-current-plot "Average Wealth"
  plot average-wealth
end
@#$#@#$#@
GRAPHICS-WINDOW
427
10
940
524
-1
-1
5.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
2
98
65
131
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
64
98
127
131
NIL
go\n
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
3
132
175
165
slider-flood-intensity
slider-flood-intensity
0
100
55.0
5
1
NIL
HORIZONTAL

SLIDER
2
165
174
198
slider-aid-amount
slider-aid-amount
0
100
58.0
1
1
NIL
HORIZONTAL

SLIDER
1
197
173
230
slider-aid-delay
slider-aid-delay
0
100
25.0
1
1
NIL
HORIZONTAL

PLOT
0
232
200
382
Flood Intensity
Ticks
Flood intensity (%)
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"flood-intensity" 1.0 0 -16777216 true "" ""

PLOT
200
231
400
381
Aid Distribution
Simulation Time (Ticks)
Total Aid Distributed (in BDT)  
0.0
100.0
0.0
100000.0
true
false
"" ""
PENS
"aid-distributed" 1.0 0 -16777216 true "" ""

PLOT
200
381
400
531
Wealth Distribution
Ticsk
Weakth in BDT
0.0
100.0
0.0
50000.0
true
false
"" ""
PENS
"average-wealth" 1.0 0 -16777216 true "" ""

PLOT
0
530
200
680
Percentage Flooded
Time in ticks 
Percentage of house holds flooded
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"percentage-flooded" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
199
531
399
681
Percentage Displaced
Percetage Displaced
Time in ticks
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"percentage-displaced" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
0
383
200
533
Reintegration Time
Time in ticks
Reintegration time in ticks
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"reintegration-time" 1.0 0 -16777216 true "" ""

PLOT
399
529
599
679
Average Wealth
Time in ticks
Wealth in BDT
0.0
100.0
0.0
50000.0
true
false
"" ""
PENS
"average-wealth-displaced" 1.0 0 -16777216 true "" "plot count turtles"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
