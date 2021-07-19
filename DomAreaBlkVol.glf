#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

package require PWI_Glyph 2

pw::Script loadTk

wm withdraw .

set BlockCount [llength [pw::Grid getAll -type pw::Block]]
set DomainCount [llength [pw::Grid getAll -type pw::Domain]]

if {0 == $DomainCount} {
  tk_messageBox -icon error -title "No Grid Entities" -message \
    "There are no suitable grid entities defined." -type ok
  exit
}

set Selection {}
set MaxNameLength 0

set Mode 0
set Label(Total,0) "TOTAL AREA"
set Label(Total,1) "TOTAL VOLUME"
set Label(Entity,0) "Domain"
set Label(Entity,1) "Block"
set Label(Metric,0) "Area"
set Label(Metric,1) "Volume"
set Type(0) "Domains"
set Type(1) "Blocks"

############################################################################
# beginTable: start generating a rich-text (HTML) report table
############################################################################
proc beginTable {} {
  global Selection Mode MaxNameLength Label Type
  set MaxNameLength [string length $Label(Total,$Mode)]
  foreach ent $Selection($Type($Mode)) {
    set nlen [string length [$ent getName]]
    if {$nlen > $MaxNameLength} {
      set MaxNameLength $nlen
    }
  }
  set table [format "\n%-${MaxNameLength}s %15s" $Label(Entity,$Mode) \
    $Label(Metric,$Mode)]
  set lines [format "%${MaxNameLength}.${MaxNameLength}s ---------------" \
    "--------------------------------------------------"]
  if {1 == $Mode} {
    append lines " -----------"
    append table " Orientation"
  }
  puts $table
  puts $lines
}

############################################################################
# tableRow: add a report row
############################################################################
proc tableRow {name value} {
  global MaxNameLength
  set row [format "%-${MaxNameLength}s %15.6f" $name $value]
  if {$value < 0.0} {
    append row " LEFT-HANDED"
  }
  puts $row
}

############################################################################
# endTable: finish the report table and write it out
############################################################################
proc endTable {total} {
  global Mode MaxNameLength Label
  puts [format "%${MaxNameLength}.${MaxNameLength}s ---------------" \
    "--------------------------------------------------"]
  puts [format "%-${MaxNameLength}s %15.6f" $Label(Total,$Mode) $total]
}

############################################################################
# select: pick domains or blocks to calculate area or volume
############################################################################
proc select {} {
  global Mode Selection

  wm withdraw .

  switch $Mode {
    1 {
      set mask [pw::Display createSelectionMask -requireBlock {Defined}]
      set prompt "Select blocks for volume calculation"
      set type Blocks
    }
    0 {
      set mask [pw::Display createSelectionMask -requireDomain {Defined}]
      set prompt "Select domains for area calculation"
      set type Domains
    }
  }

  pw::Display selectEntities -selectionmask $mask -description $prompt Selection

  if {0 == [llength $Selection($type)]} {
    wm deiconify .
  } else {
    report
    exit
  }
}

############################################################################
# report: generate the area/volume report for selected entities
############################################################################
proc report {} {
  global Selection Mode
  beginTable
  set total 0.0
  switch $Mode {
    0 {
      if { 0 < [llength $Selection(Domains)] } {
        foreach dom $Selection(Domains) {
          set exam [pw::Examine create DomainArea]
          $exam addEntity $dom
          $exam examine

          set area 0.0
          if [$dom isOfType pw::DomainUnstructured] {
            set count [$dom getCellCount]
            for { set i 1 } { $i <= $count } { incr i } {
              set area [expr $area + [$exam getValue $dom $i]]
            }
          } else {
            set dims [$dom getDimensions]
            set imax [lindex $dims 0]
            set jmax [lindex $dims 1]
            for { set i 1 } { $i < $imax } { incr i } {
              for { set j 1 } { $j < $jmax } { incr j } {
                set area [expr $area + [$exam getValue $dom "$i $j"]]
              }
            }
          }

          tableRow [$dom getName] $area
          set total [expr $total + $area]

          $exam delete
        }
      }
    }
    1 {
      if {0 < [llength $Selection(Blocks)]} {
        foreach blk $Selection(Blocks) {
          set exam [pw::Examine create BlockVolume]
          $exam addEntity $blk
          $exam examine

          set volume 0.0
          if [$blk isOfType pw::BlockExtruded] {
            # unstructured: prism
            set imax [[$blk getFace 1] getCellCount]
            set kmax [lindex [$blk getDimensions] 2]
            for { set i 1 } { $i <= $imax } { incr i } {
              for { set k 1 } { $k < $kmax } { incr k } {
                set volume [expr $volume + [$exam getValue $blk "$i 1 $k"]]
              }
            }
          } elseif [$blk isOfType pw::BlockUnstructured] {
            # unstructured: tetrahedra and pyramid
            set imax [$blk getCellCount]
            for { set i 1 } { $i <= $imax } { incr i } {
              set volume [expr $volume + [$exam getValue $blk "$i 1 1"]]
            }
          } else {
            # structured
            set dims [$blk getDimensions]
            set imax [lindex $dims 0]
            set jmax [lindex $dims 1]
            set kmax [lindex $dims 2]

            for { set i 1 } { $i < $imax } { incr i } {
              for { set j 1 } { $j < $jmax } { incr j } {
                for { set k 1 } { $k < $kmax } { incr k } {
                  set volume [expr $volume + [$exam getValue $blk "$i $j $k"]]
                }
              }
            }
          }

          tableRow [$blk getName] $volume
          if {$volume > 0.0} {
            set total [expr $total + $volume]
          } else {
            set total [expr $total - $volume]
          }
          $exam delete
        }
      }
    }
  }
  endTable $total
}

############################################################################
# makeWindow: create the Tk interface
############################################################################
proc makeWindow {} {
  global BlockCount

  label .title -text "Calculate Domain Area/Block Volume" -width 35
  set font [.title cget -font]
  .title configure -font [font create -family [font actual $font -family] \
    -weight bold]
  pack .title -expand 1 -side top
  
  frame .select -bd 1 -height 2 -relief sunken

  radiobutton .select.r0 -text Domains -variable Mode -value 0
  radiobutton .select.r1 -text Blocks -variable Mode -value 1

  if {0 == $BlockCount} {
    .select.r1 configure -state disabled
  }

  grid [label .select.l1] .select.r0 .select.r1 [label .select.l2]
  grid columnconfigure .select "0 3" -weight 1
  pack .select -fill x
 
  frame .buttons 
  button .buttons.ok -text "Select" -command { select }
  button .buttons.cancel -text "Cancel" -command { exit }

  pack .buttons.ok .buttons.cancel -padx 2 -pady 1 -side right
  pack .buttons -fill x -side bottom -pady 4

  pack [label .buttons.logo -image [cadenceLogo] -bd 0 -relief flat] \
      -side left -padx 5

  bind . <KeyPress-Escape> { .buttons.cancel invoke }
  bind . <Control-KeyPress-Return> { .buttons.ok invoke }

  wm deiconify .
}

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

makeWindow
tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
