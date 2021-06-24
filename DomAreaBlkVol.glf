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

  pack [label .buttons.logo -image [pwLogo] -bd 0 -relief flat] \
      -side left -padx 5

  bind . <KeyPress-Escape> { .buttons.cancel invoke }
  bind . <Control-KeyPress-Return> { .buttons.ok invoke }

  wm deiconify .
}

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

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
