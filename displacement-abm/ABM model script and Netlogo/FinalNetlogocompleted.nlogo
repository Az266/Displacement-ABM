; === Interface Sliders (Add in Interface Tab) ===

; === Plots (Add in Interface Tab) ===
;
; plot "% Displaced Over Time"
;   plot setup: clear-plot
;   every tick: plot percentage-displaced
;
; plot "Average Wealth Over Time"
;   plot setup: clear-plot
;   every tick: plot average-wealth
;
; plot "Turtles Flooded 2+ Times"
;   plot setup: clear-plot
;   every tick: plot count turtles with [times-flooded >= 2]
;
; plot "Cumulative Displacement"
;   plot setup: clear-plot
;   every tick: plot sum [times-flooded] of turtles
; slider aid-amount
;   min: 1000
;   max: 10000
;   default: 3000
;   increment: 500
;   units: BDT
;
; slider aid-delay
;   min: 1
;   max: 10
;   default: 2
;   increment: 1
;   units: ticks

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
]

turtles-own [
  people           ; Number of people this turtle represents
  home-patch       ; Patch they originated from
  wealth           ; Household’s BDT wealth
  displaced?       ; Whether this household is displaced
  times-flooded    ; How many times the household has been flooded
  shelter-weeks    ; Number of ticks spent in shelter
  return-delay         ; How long the turtle must wait before returning
  return-wait-time     ; How long the turtle has already waited
]

globals [
  retreat-weeks           ; Dynamic flood retreat duration based on flood intensity
  data-loaded?           ; True when terrain CSV has loaded
  flood-intensity        ; Controls severity of flood
  aid-amount             ; How much money aid provides
  aid-delay              ; How many ticks before aid arrives
  flood-tick-count       ; Ticks since flooding started
  average-wealth         ; Mean wealth of all households
  reintegration-time     ; (future) average return time
  percentage-flooded     ; % of land area flooded
  percentage-displaced   ; % of people displaced
  total-population       ; Total number of people across all turtles
  total-people-displaced ; Total number displaced
  flood-active?          ; True if flood is ongoing
  number-of-floods       ; How many floods should occur (slider input)
  show-displacement?     ; Toggle to visualize displacement
]

to setup
  print "🟢 Running setup..."
  clear-all
  set data-loaded? false
  set flood-intensity min list 1 max list 0 slider-flood-intensity
  set aid-amount slider-aid-amount
  set aid-delay slider-aid-delay
  set flood-tick-count 0
  set flood-active? true
  set number-of-floods slider-number-of-floods
  set show-displacement? false

  load-terrain-data "abm_base_grid_clean.csv"

  if data-loaded? [
    recolor-terrain-custom
    load-building-coordinates "osm_buildings.csv"
    recolor-buildings
    load-shelter-coordinates "osm_shelters.csv"
    recolor-shelters
    setup-turtles
    reset-ticks
    print "✅ Model setup complete"
  ]
end

to go
  if not data-loaded? [
    user-message "⚠️ Please load terrain data first by pressing 'setup'."
    stop
  ]

  ; === Read live flood-intensity from slider ===
  set flood-intensity slider-flood-intensity

  ; === Simulate flood dynamics ===
  flood-simulation

  ; === Apply passive wealth decay during flood ===
  if flood-active? [
    ask turtles [
      set wealth wealth * 0.998  ; lose 0.2% wealth per tick during flooding
    ]
  ]

  ; === Update turtle behaviors ===
  ask turtles [
    check-displacement
    receive-aid

    ; Apply ongoing cost of displacement
    if displaced? [
      set wealth wealth - 200  ; survival/shelter cost per tick
      if wealth < 0 [ set wealth 0 ]
    ]

    ; Cap max wealth
    if wealth > 25000 [ set wealth 25000 ]
  ]

  ; === Return home if flood ends ===
  return-home

  ; === Update monitoring ===
  set total-people-displaced sum [people] of turtles with [displaced?]
  set percentage-displaced (100 * count turtles with [displaced?] / count turtles)
  set average-wealth mean [wealth + (aid-amount / 100)] of turtles

  ; === Visual toggle ===
  if show-displacement? [
    ask turtles [
      if displaced? [ set color red ]
      if not displaced? [ set color white ]
    ]
  ]

  tick-advance 1

  ; === Plotting ===
  set-current-plot "% Displaced Over Time"
  plot percentage-displaced

  set-current-plot "Average Wealth Over Time"
  plot average-wealth

  set-current-plot "Turtles Flooded 2+ Times"
  plot count turtles with [times-flooded >= 2]

  set-current-plot "Cumulative Displacement"
  plot sum [times-flooded] of turtles

  wait 0.1
end

to flood-simulation
  let floods-per-year number-of-floods
  let flood-duration 5
  let ticks-per-year 52
  let flood-interval ticks-per-year / floods-per-year

  let flood-start? false
  let i 0
  repeat floods-per-year [
    if (ticks mod ticks-per-year) >= (i * flood-interval) and (ticks mod ticks-per-year) < ((i * flood-interval) + flood-duration) [
      set flood-start? true
    ]
    set i i + 1
  ]

  if flood-start? [
    ; === Flood phase ===
    set flood-active? true
    set flood-tick-count 0

    let base-flood-elevation mean [elevation] of patches with [water?]
    let flood-threshold base-flood-elevation + (flood-intensity * 5)
    let flood-radius floor (flood-intensity * 10) + 1

    let affected-patches patches with [not water? and elevation <= flood-threshold]
    ask affected-patches with [any? patches in-radius flood-radius with [water?]] [
      set pcolor blue + 2
    ]

    ask turtles with [not displaced? and [pcolor] of patch-here = blue + 2] [
      set color yellow
    ]
  ]

  if not flood-start? and flood-active? [
    ; === Retreat phase ===
    set flood-tick-count flood-tick-count + 1

    let max-retreat-weeks 20
    let min-retreat-weeks 1
    set retreat-weeks round (max-retreat-weeks - (flood-intensity * (max-retreat-weeks - min-retreat-weeks)))

    if flood-tick-count <= retreat-weeks [
      let flooded patches with [pcolor = blue + 2 and not water?]
      if any? flooded [
        let sorted-flooded sort-by [[a b] -> [elevation] of b < [elevation] of a] flooded
        let retreat-count ceiling (count flooded / retreat-weeks)
        let retreat-patches sublist sorted-flooded 0 (min list retreat-count length sorted-flooded)
        foreach retreat-patches [ p -> ask p [ set pcolor green ] ]
      ]
    ]
    if flood-tick-count > retreat-weeks [
      flood-cleanup
    ]
  ]
end

to flood-cleanup
  ; === Cleanup phase ===
  let remaining-flood patches with [pcolor = blue + 2 and not water?]
  if any? remaining-flood [
    ask remaining-flood [ set pcolor green ]
  ]
  set flood-active? false
  set flood-tick-count 0
end

to check-displacement
  ; Gradual displacement to avoid blocky jumps
  if not displaced? and ([pcolor] of patch-here = blue + 2) and (random-float 1 < 0.2) [
    set displaced? true
    set times-flooded times-flooded + 1
    set wealth wealth - (flood-intensity * 1200 + random 500)  ; apply flood damage to wealth
    set color red
  ]

end

to receive-aid
  if displaced? and (ticks mod aid-delay = 0) [
    set wealth wealth + aid-amount
  ]
end

to return-home
  let return-threshold (7000 - (aid-amount / 1000) * 200)
  ask turtles with [displaced?] [
    if not flood-active? [
      set return-wait-time return-wait-time + 1
      if ([pcolor] of patch-here != blue + 2) and
         (wealth >= return-threshold) and
         (return-wait-time >= return-delay) [
           move-to home-patch
           set displaced? false
           set color black
           set shelter-weeks 0
           set return-wait-time 0
      ]
    ]
    if displaced? [ set color red ]
  ]
end

; === Data Loading Utilities ===
to load-terrain-data [file-path]
  file-open file-path
  let header file-read-line

  while [not file-at-end?] [
    let line file-read-line
    let row sublist (csv:from-row line) 0 5

    let lat item 0 row
    let lon item 1 row
    let elev item 2 row
    let rain item 3 row
    let water-flag item 4 row

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
        set road? false
      ]
    ]
  ]
  file-close
  set data-loaded? true
  print "✅ Terrain grid loaded successfully"
end

to load-building-coordinates [file-path]
  file-open file-path
  let header file-read-line

  while [not file-at-end?] [
    let line csv:from-row file-read-line
    let lat item 0 line
    let lon item 1 line

    let lat-str (word lat)
    let lon-str (word lon)

    let p latlon-to-patch lat-str lon-str
    if p != nobody [
      ask p [ set house? true ]
    ]
  ]
  file-close

  ask patches [
    if not is-boolean? house? [ set house? false ]
  ]
  print "✅ Buildings loaded"
end

to load-shelter-coordinates [file-path]
  file-open file-path
  let header file-read-line

  while [not file-at-end?] [
    let line csv:from-row file-read-line
    let lat item 0 line
    let lon item 1 line

    let lat-str (word lat)
    let lon-str (word lon)

    let p latlon-to-patch lat-str lon-str
    if p != nobody [
      ask p [ set shelter? true ]
    ]
  ]
  file-close

  ask patches [
    if not is-boolean? shelter? [ set shelter? false ]
  ]
  print "✅ Shelters loaded"
end

to-report latlon-to-patch [lat lon]
  let min-lat 25.059004791682653
  let max-lat 25.12270810530306
  let min-lon 91.94666343767092
  let max-lon 92.01700436892712

  let lat-num read-from-string lat
  let lon-num read-from-string lon

  let grid-width (max-pxcor - min-pxcor)
  let grid-height (max-pycor - min-pycor)

  let px round (min-pxcor + ((lon-num - min-lon) / (max-lon - min-lon)) * grid-width)
  let py round (min-pycor + ((lat-num - min-lat) / (max-lat - min-lat)) * grid-height)

  report patch px py
end

to recolor-terrain-custom
  ask patches [
    if is-boolean? water? and water? [ set pcolor cyan ]
    if is-boolean? water? and not water? [ set pcolor green ]
  ]
end

to recolor-buildings
  ask patches with [house?] [ set pcolor brown ]
end

to recolor-shelters
  ask patches with [shelter?] [ set pcolor red ]
end

to setup-turtles
  clear-turtles
  ask patches with [house?] [
    repeat 5 [
      sprout 1 [
        set shape "person"
        set size 1.2
        set color white
        set people 5
        set wealth random 20000 + 5000
        set displaced? false
        set times-flooded 0
        set shelter-weeks 0
        set home-patch patch-here
        set return-delay random 10 + 5  ; assign individual delay
        set return-wait-time 0
      ]
    ]
  ]
  set total-population sum [people] of turtles
  set total-people-displaced 0
  print (word "✅ " count turtles " turtles created, representing " total-population " people.")
end




@#$#@#$#@
GRAPHICS-WINDOW
435
10
948
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
1
1
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
1
0.4
0.1
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
1000
10000
4000.0
500
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
1
10
3.0
1
1
NIL
HORIZONTAL

PLOT
200
228
400
378
Cumulative Displacement
Time (ticks)
Total Times Flooded  
0.0
200.0
0.0
200000.0
true
false
"" ""
PENS
"Total Times Flooded" 1.0 0 -16777216 true "" "plot sum [times-flooded] of turtles"

PLOT
199
377
399
527
Average Wealth Over Time
Time (ticks)
Average Wealth (BDT)  
0.0
100.0
0.0
5000.0
true
false
"" ""
PENS
"average-wealth" 1.0 0 -16777216 true "" "plot average-wealth"

PLOT
0
229
200
379
% Displaced Over Time
Time (Ticks)
Percent Displaced
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"percentage-displaced" 1.0 0 -16777216 true "" "plot percentage-displaced"

PLOT
0
378
200
528
Turtles Flooded 2+ Times
Time (ticks)
# of Turtles
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"Chronic Exposure" 1.0 0 -16777216 true "" "plot count turtles with [times-flooded >= 2]"

SLIDER
175
130
354
163
slider-number-of-floods
slider-number-of-floods
1
10
2.0
1
1
NIL
HORIZONTAL

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
