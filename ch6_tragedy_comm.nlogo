breed [ cows cow ]
breed [ herders herder ]

cows-own [
  owner          ; obj. each cow has a herder who's their owner
  forage         ; int. amount of grass necessary to live
]
herders-own [
  now_cows       ; int. no of cows now
  past_cows      ; int. no of cows last time step
  defector?      ; bool. did the agent defect in the last step?
]
globals [
  crisis         ; bool. are we in crisis? herders in distress > risk_level
  cost_com       ; cost of policing for the community
  cost_def       ; cost of being found out to defectors
  data           ; data collected
]



to setup
  clear-all
  ask patches [ set pcolor green ]

  ; Creates herder agents and sets their properties
  create-herders no_herders [             ; slider parameter
    move-to one-of patches
    set defector? 0
    set color white
    set size 5
    set shape "person"
  ]
  ; Creates 10 cows per agent and sets their properties
  create-cows  no_herders * 10 [
    move-to one-of patches
    set color brown
    set size 5
    set shape "cow"
  ]
  ; Assigns a random herder to each cow that doesn't have an owner yet
  ask cows with [ owner = 0 ] [
    set owner one-of herders
  ]

  ; Counts the number of cows each herder owns and sets that value as a property of the herder
  ask herders [
    set now_cows count cows with [ owner = myself ]
  ]

  ; varibales used for data collection
  set cost_com 0
  set cost_def 0
  set data []

  reset-ticks
end



to go
; reinitialise counters for data-collection
  set cost_com 0
  set cost_def 0

; Herders and cows move to a patch with more grass
  graze

; Herders evaluate the number of cows they own
 ; evaluate-stock

; Herders decide whether they commons are in danger
  govern

; Breed cows
  reproduce-herds

; Scenario (Interface switch) if the community monitors and punishes defectors
  if policing [

    monitor-and-punish

    ; the cost of policing constant and is the functon of policing effectiveness and the size of the herds (**FUTURE: do we police herders or cows?), it is paid by ALL members of the community.
    set cost_com floor (policing-effectiveness * count herders * 10)
    ; set cost_com floor (policing-effectiveness * count cows)        ; this creates a stable equilibrium
    ask n-of cost_com cows [die] ; % of cows die, chosen at random
  ]
; collect data at each time step
  data-collection

; Grass regrows on the patches
  grass-regrowth

; If there are no more cows, the simulation stops
  if not any? cows [stop]
  tick
end







;______________________ PROCEDURES _____________________________

to graze
  ; This code block is responsible for cow's grazing. Cows are moved to the closest patch with green grass and eat the grass (forage +1, patch -> black).
  ; If a cow didn't find enough grass, it will die.

 ; The code starts by setting the forage of all cows to 0
  ask cows [ set forage 0 ]

  ; While the maximum forage of any cow is less than the required forage and there are still green patches
  while [ max [forage] of cows < cow-forage-requirement and any? patches with [ pcolor = green ]] [

    ; Cows move to the closest patch with green grass and eat the grass
    ask cows with [forage < cow-forage-requirement] [
      if any? patches with [ pcolor = green ] [
        move-to min-one-of patches with [ pcolor = green ] [ distance myself ]
        set pcolor black                                ; grass eaten
        set forage forage + 1                           ; cow fed + 1
      ]
    ]
  ]

  ; If a cow didn't find enough grass it will die
  ask cows [
    if forage < cow-forage-requirement [ die ]
  ]
end

to govern
  ; Community decision making. Agents decide whether the commons are depleated based on the number of herders with dead stock **FUTURE dynamic risk-level

  ; count herders in distress i.e. with at least one dead cow
  let distressed_herders 0
  ask herders  [
    set distressed_herders distressed_herders + evaluate-stock
    print distressed_herders
    if now_cows = 0 [die]                                      ; no more cows, the herder is not a herder any more (they don't really die, just move to an office job in the nearby city)
  ]
  ifelse distressed_herders > risk_level * count herders       ; if no of herders in distress > community risk level
     [set crisis 1]                                            ; trigger CRISIS MODE
     [set crisis 0]                                            ; else maintain or change into no-crisis mode

end


to-report evaluate-stock
  ; herders evaluate whether they want to expand the herd based on the current number of cows and the level of selfishness


    set past_cows now_cows                             ; cows the herder had in the last time step
    set now_cows count cows with [ owner = myself ]    ; current number of cows


    ifelse past_cows > now_cows                        ; if cows died of hunger report 1 otherwise 0
       [ report 1 ]
       [ report 0 ]



end

to reproduce-herds
  ; Two options:
  ; 1. We're NOT in a crisis: herders will reproduce cows normally.
  ; 2. We ARE in a crisis: herders  have a chance to become defectors with a probability of selfishness, and reproduce cows despite the ban

 ; 1. NO CRISIS
  ifelse crisis = 0 [
    ask herders [
      make-a-cow                                   ; ALL herders reproduce cows
      set defector? 0                              ; reset everyone status
    ]
  ]
  ; 2. YES CRISIS
  [
    ask herders[
      if random-float 1 < selfishness [            ; ONLY SELFISH herders reproduce cows
        set defector? 1                            ; currently the level of selfishness is a constant **FUTURE inheritable from parents **FUTURE depends on punishment (not punished - goes up, punished - goes down)
        make-a-cow
      ]
    ]
  ]

end

to make-a-cow
  ; produce new cows (cows inherit all var from parents)
   let mycows cows with [owner = myself]
   if any? mycows [                                 ; fall safe, ** FUTURE can be axed given the opening condition
      ask one-of mycows [hatch 3]                   ; **FUTURE cows hatched should be a proportion of the herd, they could also be proportional to the resources left
  ]
end

to monitor-and-punish

  let defectors herders with [defector? = 1]        ; defectors

  ask defectors [
    if random-float 1 < policing-effectiveness [    ; have a chance of being caught
      let mycows cows with [owner = myself]
      ifelse count mycows > 2 [
        ask n-of 2 mycows [die]                     ; angry mob kills two of their cows
      ]
      [ask mycows [die]                             ; if they have fewer than 3 cows we finish off their herd
       die                                          ; and they cease to be a herder
      ]
      set cost_def cost_def + 1                     ; data collection
    ]
  ]
end


to grass-regrowth
  ; grass regrowths with a given probability          **FUTURE gradual regrowth
  ask patches with [pcolor = black] [                 ; only dead grass gridcells **FUTURE TEST check how this affects the regrowth rates gloabally (e.g few cows, few black patches, low overal regrowth)
    if random-float 1 < grass-regrowth-rate [         ; slider parameter: grass-regrowth-rate
       set pcolor green                               ; grass regrown

    ]
  ]
end
to data-collection

  ; collect variables of interest
  let no-herders count herders
  let no-cows count cows
  let no-dead-grass count patches with [pcolor = black ]
  let no-defectors count herders with [defector? = 1]

  ; collect data from this time step into one nifty list
  let data_tick  (list no-herders no-cows no-dead-grass crisis no-defectors cost_com cost_def)

  ;  collect long-term data for analysis
  set data fput data_tick data
end
@#$#@#$#@
GRAPHICS-WINDOW
600
10
1274
685
-1
-1
6.6
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
35
20
98
53
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
102
20
165
53
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
167
20
230
53
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
30
460
205
493
cow-forage-requirement
cow-forage-requirement
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
30
520
202
553
grass-regrowth-rate
grass-regrowth-rate
0
1
0.8
.1
1
NIL
HORIZONTAL

SLIDER
30
235
202
268
selfishness
selfishness
0
1
0.5
0.1
1
NIL
HORIZONTAL

PLOT
1315
10
1750
315
Agents populations
Time
Cows
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"cows" 1.0 0 -14439633 true "" "plot count cows"
"herders" 1.0 0 -5825686 true "" "plot count herders"

TEXTBOX
255
20
540
116
To run the model, click first on \"setup\" then on \"go\"; \"step\" moves the model one time step). Use the sliders to change the parameters. \n\nMore info in the Info Tab.
11
12.0
1

TEXTBOX
35
435
185
453
Cows
13
105.0
1

TEXTBOX
30
500
180
518
The environement
13
64.0
1

TEXTBOX
40
170
190
188
People
13
125.0
1

PLOT
1315
330
1820
680
defectors and policing
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
"no of defectors" 1.0 0 -5825686 true "" "plot count herders with [defector? = 1]"
"cost to defectors" 1.0 0 -13360827 true "" "plot cost_def"
"cost to the community" 1.0 0 -6995700 true "" "plot cost_com"

SLIDER
30
195
202
228
no_herders
no_herders
1
50
30.0
1
1
NIL
HORIZONTAL

TEXTBOX
215
210
365
228
Inital no of herders
11
0.0
1

TEXTBOX
215
250
405
291
Probability of defecting during \"crisis\"
11
0.0
1

SLIDER
30
275
202
308
risk_level
risk_level
0
1
0.5
0.01
1
NIL
HORIZONTAL

TEXTBOX
215
280
440
321
Percentage of herders in distress that's acceptable for everyone to make more cows
11
0.0
1

SWITCH
30
315
200
348
policing
policing
0
1
-1000

TEXTBOX
215
320
410
361
Scenario with community monitoring and punishing defectors (inv. cost)
11
0.0
1

SLIDER
30
355
202
388
policing-effectiveness
policing-effectiveness
0
1
0.3
0.1
1
NIL
HORIZONTAL

TEXTBOX
215
360
365
386
Probability of detecting and punishing a defector
11
0.0
1

PLOT
1315
690
1700
840
crisis
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot crisis"

TEXTBOX
40
630
190
726
example equilibrium scenarios\n1. stable\n30-0.5-0.5-0.50-0.3-15-0.8\n2. fluctuation\n30-0.5-0.5-0.50-0.2-15-0.8\n3. all dead\n30-0.5-0.5-0.25-0.2-15-0.8
11
0.0
1

TEXTBOX
405
685
555
703
NIL
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

A simple implementation of the Tragedy of the Commons model. This is a simplified version of the MASTOC model by Schindler.
Schindler, Julia. 2012. “A Simple Agent-Based Model Of The Tragedy Of The Commons.” In ECMS 2012 Proceedings Edited by: K. G. Troitzsch, M. Moehring, U. Lotzmann, 44–50. ECMS. https://doi.org/10.7148/2012-0044-0050.

This is an example model used in chapter 6 of Romanowska, I., Wren, C., Crabtree, S. 2021. Agent-Based Modeling for Archaeology: Simulating the Complexity of Societies. Santa Fe, NM: SFI Press. Code blocks: 6.24-6.27

The model was further developed to include E. Ostrom 8 Design principles.
DOI: 10.1017/CBO9780511807763



## HOW IT WORKS

Cows move around and consume grass. Grass regrows with a probability set by a slider.
In the original implementation eventually cows eat all the grass and die. Here, the governance is introduced to prevent the tragedy. For this agent need to communicate and cooperate.

Herders enlarge their herds until a "crisis mode" is triggered. This happens when more than "risk-level" (slider) herders are in distress (ie. lost a cow from starvation). 
In crisis mode herders are not supposed to enlarge their herds. However, each has a probability "selfishness" (slider) of defecting and reproducing the herd nevertheless. 

If "policing" (switch) is on. The community carries the cost of policing (this is a constant cost regardless of the probability of defection). If a defector is caught they lose 2 cows. 


## HOW TO USE IT

Press setup, press go. 
Use sliders to change the parameters:

no-herders - initial number of herders
selfishness - probablility of defecting 
risk-level - percent of herders in distress that triggers "crisis mode"
policing - scenario with or without policing
policing-effectiveness - probability of catching a defector

cow-forage-requirement - how much does a cow need to eat
grass-regrowth-rate - rate of grass regrowth 

## THINGS TO NOTICE

The tragedy of the commons,supposedly always ends in a tragedy (altho the time needed to reach it may vary. In fact it has 3 equilibria (all cows dead, stable and regular fluctuation - lottka volterra style). 

Scenarios to test: 
- vary risk level - it gives quite counterintuitive results
- cow-forage-requirement - is a significant factor


## RELATED MODELS

There's a HubNet version of the Tragedy of the Commons available in the NetLogo Models Library.
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
NetLogo 6.3.0
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
1
@#$#@#$#@
