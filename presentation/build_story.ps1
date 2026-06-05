# ============================================================
#  Welcome2GH - "Amara's Journey" (story-driven, bold 3D)
#  University defense deck - built via PowerPoint COM
# ============================================================
$ErrorActionPreference = 'Stop'
$root   = "C:\Users\Mohamed\Desktop\App W2G"
$outDir = Join-Path $root "presentation"
$qaDir  = Join-Path $outDir "qa"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $qaDir  | Out-Null
$pptxPath = Join-Path $outDir "Welcome2GH_Presentation.pptx"
if (Test-Path $pptxPath) { Remove-Item $pptxPath -Force }

function C($r,$g,$b){ [int]($r + $g*256 + $b*65536) }
$Navy=C 13 27 42; $NavyTop=C 22 38 58; $NavyDeep=C 6 13 22
$Card=C 26 37 53; $CardLite=C 33 47 67
$Gold=C 255 204 0; $GoldDeep=C 196 150 8
$White=C 245 247 250; $Muted=C 150 166 188; $Border=C 40 54 76
$Green=C 67 160 71; $Red=C 229 57 53; $Blue=C 64 132 240
$RedSoft=C 255 138 138; $GreenSoft=C 138 230 150

$Fhead="Segoe UI Black"; $Fsemi="Segoe UI Semibold"; $Fbody="Segoe UI"
$Flight="Segoe UI Light"; $Femoji="Segoe UI Emoji"

$RECT=1; $ROUND=5; $OVAL=9; $ARROW=33
$AL=1; $AC=2; $AR=3
$VT=1; $VM=3; $VB=4

$pp = New-Object -ComObject PowerPoint.Application
$pp.DisplayAlerts = 1
try { $pp.Visible = -1 } catch {}
$pres = $pp.Presentations.Add(-1)
$pres.PageSetup.SlideWidth  = 960
$pres.PageSetup.SlideHeight = 540
try { foreach($w in $pp.Windows){ $w.WindowState = 2 } } catch {}

# ---------- helpers ----------
function New-Slide {
    $s = $pres.Slides.Add($pres.Slides.Count + 1, 12)
    $s.FollowMasterBackground = 0
    $s.Background.Fill.Visible = -1
    $s.Background.Fill.TwoColorGradient(4,1)
    $s.Background.Fill.ForeColor.RGB = $script:NavyTop
    $s.Background.Fill.BackColor.RGB = $script:NavyDeep
    return $s
}
function Glow($s,$x,$y,$d,$col,$trans){
    $o = $s.Shapes.AddShape($script:OVAL,$x,$y,$d,$d)
    $o.Line.Visible = 0
    $o.Fill.Solid(); $o.Fill.ForeColor.RGB = $col; $o.Fill.Transparency = ($trans/100.0)
    try { $o.Shadow.Visible = 0 } catch {}
    return $o
}
function Shadow($shp,$blur,$ox,$oy,$tr){
    try {
        $shp.Shadow.Visible=-1; $shp.Shadow.Style=1; $shp.Shadow.ForeColor.RGB=0
        $shp.Shadow.Blur=$blur; $shp.Shadow.OffsetX=$ox; $shp.Shadow.OffsetY=$oy; $shp.Shadow.Transparency=$tr
    } catch {}
}
function Bevel($shp,$depth,$extCol,$btype,$inset){
    try {
        $shp.ThreeD.Visible=-1; $shp.ThreeD.BevelTopType=$btype; $shp.ThreeD.BevelTopInset=$inset; $shp.ThreeD.BevelTopDepth=4
        if($depth -gt 0){ $shp.ThreeD.Depth=$depth; $shp.ThreeD.ExtrusionColorType=2; $shp.ThreeD.ExtrusionColor.RGB=$extCol }
    } catch {}
}
function Card($s,$x,$y,$w,$h,$fill,$line){
    $c = $s.Shapes.AddShape($script:ROUND,$x,$y,$w,$h)
    try { $c.Adjustments.Item(1) = 0.07 } catch {}
    $c.Fill.Solid(); $c.Fill.ForeColor.RGB = $fill
    if($line -ge 0){ $c.Line.Visible=-1; $c.Line.ForeColor.RGB=$line; $c.Line.Weight=1 } else { $c.Line.Visible=0 }
    Shadow $c 14 0 8 0.55
    Bevel $c 7 ([int]($fill - 0x080808)) 2 5
    return $c
}
function Txt($s,$x,$y,$w,$h,$text,$size,$color,$font,$bold,$align,$vanch){
    $tb = $s.Shapes.AddTextbox(1,$x,$y,$w,$h)
    $tb.TextFrame.WordWrap = -1
    try { $tb.TextFrame.AutoSize = 0 } catch {}
    $tb.TextFrame.MarginLeft=0; $tb.TextFrame.MarginRight=0; $tb.TextFrame.MarginTop=0; $tb.TextFrame.MarginBottom=0
    try { $tb.TextFrame.VerticalAnchor = [int]$vanch } catch {}
    $tr = $tb.TextFrame.TextRange
    $tr.Text = [string]$text
    $tr.Font.Size = [single]$size
    $tr.Font.Name = [string]$font
    $tr.Font.Color.RGB = [int]$color
    try { $tr.Font.Bold = $(if($bold){-1}else{0}) } catch {}
    try { $tr.ParagraphFormat.Alignment = [int]$align } catch {}
    return $tb
}
function Header($s,$kicker,$title){
    $bar = $s.Shapes.AddShape($script:ROUND,60,44,8,40)
    try { $bar.Adjustments.Item(1)=0.5 } catch {}
    $bar.Line.Visible=0; $bar.Fill.Solid(); $bar.Fill.ForeColor.RGB=$script:Gold
    Bevel $bar 6 $script:GoldDeep 8 4
    Txt $s 80 40 820 22 $kicker 13 $script:Gold $script:Fsemi $true $AL $VT | Out-Null
    Txt $s 79 58 840 40 $title 29 $script:White $script:Fhead $true $AL $VT | Out-Null
}
function Footer($s,$n){
    Txt $s 60 512 300 18 "Welcome2GH  ·  Amara's Journey" 10 $script:Muted $script:Fbody $false $AL $VM | Out-Null
    Txt $s 660 512 240 18 $n 10 $script:Gold $script:Fbody $false $AR $VM | Out-Null
}
function IconDisc($s,$x,$y,$d,$emoji,$discCol){
    $disc = $s.Shapes.AddShape($script:OVAL,$x,$y,$d,$d)
    $disc.Line.Visible=0; $disc.Fill.Solid(); $disc.Fill.ForeColor.RGB=$discCol
    Shadow $disc 8 0 4 0.5
    Bevel $disc 4 ([int]($discCol-0x101010)) 8 4
    Txt $s $x ($y+1) $d $d $emoji ([int]($d*0.5)) $script:White $script:Femoji $false $AC $VM | Out-Null
    return $disc
}
function Phone($s,$cx,$cy,$targetH,$imgRel,$ry){
    $imgPath = Join-Path $script:root $imgRel
    $w = [double]($targetH * 0.45); $x = $cx - $w/2.0; $y = $cy - $targetH/2.0
    $frame = $s.Shapes.AddShape($script:ROUND,($x-7),($y-7),($w+14),($targetH+14))
    try { $frame.Adjustments.Item(1)=0.13 } catch {}
    $frame.Fill.Solid(); $frame.Fill.ForeColor.RGB=(C 8 12 18)
    $frame.Line.Visible=-1; $frame.Line.ForeColor.RGB=$script:Gold; $frame.Line.Weight=1.5
    Shadow $frame 26 0 16 0.45
    $pic = $s.Shapes.AddPicture($imgPath,0,-1,$x,$y,$w,$targetH)
    $nm1="phf_$($s.SlideIndex)"; $nm2="php_$($s.SlideIndex)"; $frame.Name=$nm1; $pic.Name=$nm2
    try {
        $grp = $s.Shapes.Range(@($nm1,$nm2)).Group()
        $grp.ThreeD.Visible=-1; $grp.ThreeD.RotationY=$ry; $grp.ThreeD.RotationX=-4; $grp.ThreeD.FieldOfView=38
        return $grp
    } catch { return $frame }
}
function Bullets($s,$x,$y,$w,$h,$items,$size,$color){
    $tb = $s.Shapes.AddTextbox(1,$x,$y,$w,$h)
    $tb.TextFrame.WordWrap=-1
    try { $tb.TextFrame.AutoSize=0 } catch {}
    $tb.TextFrame.MarginLeft=0;$tb.TextFrame.MarginRight=0;$tb.TextFrame.MarginTop=0;$tb.TextFrame.MarginBottom=0
    $tr=$tb.TextFrame.TextRange
    $tr.Text=($items -join "`r")
    $tr.Font.Size=[single]$size; $tr.Font.Name=$script:Fbody; $tr.Font.Color.RGB=[int]$color
    $tr.ParagraphFormat.Alignment=$AL
    try {
        $tr.ParagraphFormat.Bullet.Visible=-1; $tr.ParagraphFormat.Bullet.Character=8226
        $tr.ParagraphFormat.Bullet.Font.Color.RGB=$script:Gold
        $tr.ParagraphFormat.SpaceAfter=10; $tr.ParagraphFormat.SpaceBefore=0
    } catch {}
    return $tb
}
# narration paragraph (story voice)
function Narrate($s,$x,$y,$w,$h,$text,$size){
    $tb=$s.Shapes.AddTextbox(1,$x,$y,$w,$h); $tb.TextFrame.WordWrap=-1
    try{$tb.TextFrame.AutoSize=0}catch{}
    $tb.TextFrame.MarginLeft=0;$tb.TextFrame.MarginRight=0;$tb.TextFrame.MarginTop=0;$tb.TextFrame.MarginBottom=0
    $tb.TextFrame.VerticalAnchor=$VT
    $tr=$tb.TextFrame.TextRange; $tr.Text=[string]$text
    $tr.Font.Size=[single]$size; $tr.Font.Name=$script:Fbody; $tr.Font.Color.RGB=$script:White
    $tr.ParagraphFormat.Alignment=$AL
    try { $tr.ParagraphFormat.SpaceAfter=8; $tr.ParagraphFormat.LineRuleWithin=$true; $tr.ParagraphFormat.SpaceWithin=1.1 } catch {}
    return $tb
}
# subtle "powered by" footnote with a gold dot
function TechFoot($s,$x,$y,$w,$text){
    $dot=$s.Shapes.AddShape($script:OVAL,$x,($y+5),9,9); $dot.Line.Visible=0; $dot.Fill.Solid(); $dot.Fill.ForeColor.RGB=$script:Gold
    Txt $s ($x+18) $y ($w-18) 40 $text 12 $script:Gold $script:Fsemi $false $AL $VT | Out-Null
}
# small chip
function Chip($s,$x,$y,$text){
    $pw = 16 + ([string]$text).Length*7.2
    $p=$s.Shapes.AddShape($script:ROUND,$x,$y,$pw,28); try{$p.Adjustments.Item(1)=0.5}catch{}
    $p.Line.Visible=-1;$p.Line.ForeColor.RGB=$script:Border;$p.Line.Weight=1; $p.Fill.Solid(); $p.Fill.ForeColor.RGB=$script:Card
    Shadow $p 5 0 2 0.6
    Txt $s $x $y $pw 28 $text 11.5 $script:Gold $script:Fsemi $true $AC $VM | Out-Null
    return ($x + $pw + 10)
}
# 3D extruded hero word (no frame artifact)
function Hero3D($s,$x,$y,$w,$h,$text,$size,$centerY){
    $t=Txt $s $x $y $w $h $text $size $script:Gold $script:Fhead $true $AC $VM
    try {
        $t.Line.Visible=0; $t.Fill.Visible=0; $t.TextFrame.WordWrap=0; $t.TextFrame.AutoSize=1
        $t.Top = $centerY - $t.Height/2.0; $t.Left = (960 - $t.Width)/2.0
        $t.ThreeD.Visible=-1; $t.ThreeD.BevelTopType=8; $t.ThreeD.BevelTopInset=6
        $t.ThreeD.Depth=14; $t.ThreeD.ExtrusionColorType=2; $t.ThreeD.ExtrusionColor.RGB=$script:GoldDeep
    } catch {}
    return $t
}

# =====================================================================
#  S1 — COLD OPEN / TITLE
# =====================================================================
$s = New-Slide
Glow $s 520 -120 620 $Gold 88 | Out-Null
Glow $s -160 300 520 $Blue 90 | Out-Null
$logo = $s.Shapes.AddPicture((Join-Path $root "assets\images\logo.png"),0,-1,440,46,80,77); Shadow $logo 18 0 8 0.4
Txt $s 80 138 800 20 "WELCOME2GH  ·  A STORY ABOUT BELONGING IN A NEW CITY" 13 $Gold $Fsemi $true $AC $VT | Out-Null
Hero3D $s 80 160 800 110 "Akwaaba." 74 215 | Out-Null
Txt $s 150 285 660 40 "Every newcomer deserves to feel at home. This is the story of how one of them did." 18 $White $Fsemi $false $AC $VT | Out-Null
$pc = Card $s 250 372 460 64 $Card $Border
Txt $s 270 380 420 20 "Mohamed" 16 $White $Fsemi $true $AC $VT | Out-Null
Txt $s 270 404 420 18 "Wisconsin International University College (WIUC)  ·  Accra, 2026" 12 $Muted $Fbody $false $AC $VT | Out-Null
Txt $s 80 456 800 22 "LIVE  ·  welcome2gh.vercel.app" 13 $Gold $Fsemi $true $AC $VM | Out-Null

# =====================================================================
#  S2 — MEET AMARA
# =====================================================================
$s = New-Slide
Glow $s 760 -120 520 $Gold 90 | Out-Null
Header $s "ACT I  ·  ARRIVAL" "Meet Amara"
# avatar monogram
$av = $s.Shapes.AddShape($OVAL,95,175,210,210); $av.Line.Visible=-1; $av.Line.ForeColor.RGB=$GoldDeep; $av.Line.Weight=2
$av.Fill.Solid(); $av.Fill.ForeColor.RGB=$Gold; Shadow $av 22 0 12 0.45; Bevel $av 10 $GoldDeep 8 6
Txt $s 95 178 210 210 "A" 120 $Navy $Fhead $true $AC $VM | Out-Null
Txt $s 95 396 210 22 "first time in Accra" 13 $Muted $Fbody $false $AC $VT | Out-Null
# bio
Txt $s 360 178 520 34 "Amara" 36 $White $Fhead $true $AL $VT | Out-Null
Txt $s 360 220 520 22 "21  ·  International student  ·  From Lagos, Nigeria" 15 $Gold $Fsemi $true $AL $VT | Out-Null
Narrate $s 360 256 510 110 "Today she lands in Accra for the very first time - a new face at WIUC, four hundred miles and a whole border from everything familiar. She is full of hope. She is also completely on her own." 16 | Out-Null
$cx = Chip $s 360 372 "First time in Ghana"
$cx = Chip $s $cx 372 "Knows no one yet"
$cx = Chip $s $cx 372 "One phone, one dream"
Footer $s "Act I"

# =====================================================================
#  S3 — DAY ONE (the city tests her) = the problem, as a scene
# =====================================================================
$s = New-Slide
Glow $s 640 -140 520 $Red 91 | Out-Null
Header $s "ACT I  ·  DAY ONE" "The City Starts to Test Her"
Narrate $s 60 128 840 24 "She steps out of Kotoka Airport into the noise and the heat. Within hours, Accra asks three questions she cannot answer." 15.5 | Out-Null
$beats = @(
  @("🧭","Which way is home?","The streets blur together. Every junction looks the same, and the map on her phone does not speak Accra."),
  @("💸","Is this the real price?","A taxi driver names a number. She has no idea it is three times too high. Tired and unsure, she pays."),
  @("⚠️","Is it safe here?","A classmate warns, 'don't go there after dark.' But Amara has no way of knowing where 'there' even is.")
)
$cw=276;$ch=250;$sx=60;$sy=180;$gap=18
for($i=0;$i -lt 3;$i++){
    $x=$sx+$i*($cw+$gap)
    Card $s $x $sy $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+($cw/2)-30) ($sy+24) 60 $beats[$i][0] (C 42 30 30) | Out-Null
    Txt $s ($x+18) ($sy+98) ($cw-36) 26 $beats[$i][1] 17 $White $Fsemi $true $AC $VT | Out-Null
    Txt $s ($x+20) ($sy+132) ($cw-40) 110 $beats[$i][2] 13 $Muted $Fbody $false $AC $VT | Out-Null
}
Footer $s "Act I"

# =====================================================================
#  S4 — THE WALL (emotional low point)
# =====================================================================
$s = New-Slide
Glow $s 480 360 620 $Red 92 | Out-Null
Glow $s -160 -160 460 $Blue 92 | Out-Null
Txt $s 80 150 800 50 "By the end of her first week," 30 $White $Flight $false $AC $VM | Out-Null
Txt $s 80 198 800 60 "Accra felt less like a welcome" 40 $White $Fhead $true $AC $VM | Out-Null
Txt $s 80 262 800 60 "and more like a wall." 40 $Gold $Fhead $true $AC $VM | Out-Null
Txt $s 180 350 600 30 "She was not unwelcome. She was just unguided." 17 $Muted $Fbody $false $AC $VM | Out-Null

# =====================================================================
#  S5 — THE TURNING POINT (enter Welcome2GH)
# =====================================================================
$s = New-Slide
Glow $s 720 -120 560 $Gold 88 | Out-Null
Header $s "ACT II  ·  THE TURN" "Then a Classmate Showed Her One App"
Phone $s 250 322 358 "_emu_login.png" 20 | Out-Null
Narrate $s 470 158 430 120 "Welcome2GH. A guide built for exactly this moment - made by someone who had arrived as a stranger too. For the first time since she landed, Amara was not facing Accra alone." 16 | Out-Null
Bullets $s 470 300 430 170 @(
  "Find her way - confidently",
  "Pay what locals pay",
  "Ask anything, anytime",
  "Belong to a community",
  "Know where is safe"
) 15 $White | Out-Null
Footer $s "Act II"

# =====================================================================
#  S6 — SCENE ONE: finds her way (navigation)
# =====================================================================
$s = New-Slide
Glow $s -160 300 520 $Blue 90 | Out-Null
Header $s "ACT II  ·  SCENE ONE" "Finally, She Knew Where She Was"
Phone $s 760 322 358 "_emu_shot2.png" -20 | Out-Null
Narrate $s 60 158 560 150 "The map knew Accra better than she did. Live directions that actually fit the city. Real walking and taxi times, not guesses. And a glowing dot that followed her every step of the way home. No more wrong turns. No more standing on a corner, lost." 17 | Out-Null
TechFoot $s 60 392 560 "Powered by OpenStreetMap + OSRM routing + live GPS - turn-by-turn, no API keys."
Footer $s "Act II"

# =====================================================================
#  S7 — SCENE TWO: stops overpaying (fair price)
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Gold 89 | Out-Null
Header $s "ACT II  ·  SCENE TWO" "The Next Driver Tried the Same Trick"
Narrate $s 60 150 500 140 "But this time, Amara already knew the fair price - submitted and verified by people who had stood exactly where she stood. She smiled, named the real number, and paid it. A small moment. A huge feeling." 17 | Out-Null
# fare comparison
$bad = Card $s 600 175 300 110 (C 42 26 26) (C 90 50 50)
Txt $s 600 188 300 20 "WHAT TOURISTS PAY" 12 $RedSoft $Fsemi $true $AC $VT | Out-Null
Txt $s 600 210 300 60 "GHS 60" 40 $RedSoft $Fhead $true $AC $VT | Out-Null
$dn=$s.Shapes.AddShape($ARROW,720,292,60,26); $dn.Rotation=90; $dn.Line.Visible=0; $dn.Fill.Solid(); $dn.Fill.ForeColor.RGB=$Gold; Shadow $dn 6 0 3 0.5
$good = Card $s 600 330 300 110 (C 22 40 26) (C 50 92 56)
Txt $s 600 343 300 20 "THE FAIR PRICE" 12 $GreenSoft $Fsemi $true $AC $VT | Out-Null
Txt $s 600 365 300 60 "GHS 20" 40 $GreenSoft $Fhead $true $AC $VT | Out-Null
TechFoot $s 60 392 500 "Community-reported, verified prices - so no one pays the 'visitor tax'."
Footer $s "Act II"

# =====================================================================
#  S8 — SCENE THREE: Accra answers (AI)
# =====================================================================
$s = New-Slide
Glow $s -140 -130 500 $Blue 90 | Out-Null
Glow $s 720 340 460 $Gold 91 | Out-Null
Header $s "ACT II  ·  SCENE THREE" "She Asked. Accra Answered."
IconDisc $s 110 195 150 "🤖" (C 36 30 14) | Out-Null
$q = Card $s 300 180 600 96 $Card $Border
Txt $s 322 192 556 72 '"Where can I find good, safe, fairly-priced jollof near Osu - and is it okay to walk there tonight?"' 16 $Gold $Flight $false $AL $VM | Out-Null
Narrate $s 300 296 600 110 "The AI guide replied like a local friend who never sleeps - a recommendation, a route, and a little reassurance. Amara realised she could simply ask Accra anything, and it would answer in her language, in seconds." 16 | Out-Null
TechFoot $s 110 408 790 "Claude AI, served securely through a Supabase Edge Function - no keys ever shipped in the app."
Footer $s "Act II"

# =====================================================================
#  S9 — SCENE FOUR: she belongs (community)
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Gold 89 | Out-Null
Header $s "ACT II  ·  SCENE FOUR" "Slowly, Accra Stopped Feeling So Big"
Narrate $s 60 128 840 24 "She was not the first to arrive knowing no one. And the people who came before had left a trail for her to follow." 15.5 | Out-Null
$comm = @(
  @("⚡","A living feed","Questions answered in minutes, by people who get it."),
  @("⭐","Honest reviews","Real photos and ratings - places worth her time."),
  @("📍","Hidden gems","Spots she would never have found, shared by locals."),
  @("❤️","A place to belong","Accra started to feel less like a city, more like a community.")
)
$cw=400;$ch=104;$gx=60;$gy=180;$ax=40;$ay=18
for($i=0;$i -lt 4;$i++){
    $col=$i%2;$row=[int]([math]::Floor($i/2))
    $x=$gx+$col*($cw+$ax);$y=$gy+$row*($ch+$ay)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+20) ($y+22) 52 $comm[$i][0] (C 40 34 14) | Out-Null
    Txt $s ($x+88) ($y+18) ($cw-108) 24 $comm[$i][1] 16 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+88) ($y+46) ($cw-108) 48 $comm[$i][2] 12.5 $Muted $Fbody $false $AL $VT | Out-Null
}
Footer $s "Act II"

# =====================================================================
#  S10 — SCENE FIVE: she stays safe (alerts)
# =====================================================================
$s = New-Slide
Glow $s -150 320 500 $Blue 91 | Out-Null
Header $s "ACT II  ·  SCENE FIVE" "When It Wasn't Safe, She Knew First"
Narrate $s 60 158 520 150 "The map did not just show her where to go. It showed her where not to. Danger zones drawn with a real radius. Alerts that reached her before she arrived, not after. Accra felt less like a risk to survive, and more like a place she could explore." 17 | Out-Null
TechFoot $s 60 392 520 "Geo-fenced safety alerts with a real radius and auto-expiry."
# mini map visual
$map = Card $s 610 175 290 230 (C 18 28 44) $Border
$road1=$s.Shapes.AddShape($RECT,610,300,290,10); $road1.Line.Visible=0; $road1.Fill.Solid(); $road1.Fill.ForeColor.RGB=(C 34 48 70)
$road2=$s.Shapes.AddShape($RECT,740,175,10,230); $road2.Line.Visible=0; $road2.Fill.Solid(); $road2.Fill.ForeColor.RGB=(C 34 48 70)
$zone=$s.Shapes.AddShape($OVAL,790,205,90,90); $zone.Line.Visible=-1; $zone.Line.ForeColor.RGB=$Red; $zone.Line.Weight=1.5; $zone.Fill.Solid(); $zone.Fill.ForeColor.RGB=$Red; $zone.Fill.Transparency=0.62
Txt $s 786 238 98 20 "ALERT" 10 $RedSoft $Fsemi $true $AC $VM | Out-Null
$dot=$s.Shapes.AddShape($OVAL,672,330,20,20); $dot.Line.Visible=-1; $dot.Line.ForeColor.RGB=$White; $dot.Line.Weight=1.5; $dot.Fill.Solid(); $dot.Fill.ForeColor.RGB=$Gold; Shadow $dot 8 0 0 0.3
Txt $s 632 352 120 18 "Amara" 11 $White $Fsemi $true $AC $VT | Out-Null
Footer $s "Act II"

# =====================================================================
#  S11 — TRANSFORMATION
# =====================================================================
$s = New-Slide
Glow $s 700 -120 560 $Gold 88 | Out-Null
Header $s "ACT III  ·  THREE MONTHS LATER" "A Different Story"
Narrate $s 60 128 840 24 "Same city. Same Amara. A completely different experience." 16 | Out-Null
$then = Card $s 60 178 400 240 (C 36 26 30) (C 80 52 58)
Txt $s 84 194 352 24 "DAY ONE" 13 $RedSoft $Fsemi $true $AL $VT | Out-Null
Bullets $s 84 230 352 170 @("Lost in unfamiliar streets","Overcharged at every turn","Anxious about where was safe","Far from home, and alone") 15 $White | Out-Null
$arw=$s.Shapes.AddShape($ARROW,470,278,20,40); $arw.Line.Visible=0; $arw.Fill.Solid(); $arw.Fill.ForeColor.RGB=$Gold; Shadow $arw 8 0 4 0.4
$now = Card $s 500 178 400 240 (C 22 40 28) (C 50 92 58)
Txt $s 524 194 352 24 "TODAY" 13 $GreenSoft $Fsemi $true $AL $VT | Out-Null
Bullets $s 524 230 352 170 @("Moves through Accra with ease","Always pays the fair price","Explores new places freely","Part of a community - at home") 15 $White | Out-Null
Footer $s "Act III"

# =====================================================================
#  S12 — AKWAABA, KEPT (theme / mission)
# =====================================================================
$s = New-Slide
Glow $s 480 -150 700 $Gold 86 | Out-Null
Glow $s -180 320 520 $Blue 90 | Out-Null
Txt $s 80 150 800 44 "'Akwaaba' means welcome." 28 $White $Flight $false $AC $VM | Out-Null
Txt $s 80 214 800 110 "Welcome2GH makes sure Accra keeps that promise." 36 $Gold $Fhead $true $AC $VM | Out-Null
Txt $s 160 358 640 30 "For every Amara who arrives far from home." 18 $White $Fsemi $false $AC $VM | Out-Null
Txt $s 160 406 640 24 "Designed in Ghana's colours  ·  named for its welcome  ·  built with Adinkra spirit" 13 $Muted $Fbody $false $AC $VM | Out-Null

# =====================================================================
#  S13 — HOW HER STORY IS POWERED (architecture)
# =====================================================================
$s = New-Slide
Glow $s -160 320 520 $Blue 91 | Out-Null
Header $s "BEHIND THE STORY  ·  ENGINEERING" "Every Scene Runs on Real Engineering"
Txt $s 60 126 840 22 "Amara is fiction. The technology behind her story is not." 14 $Muted $Fbody $false $AL $VT | Out-Null
$layers = @(
  @("📱","Frontend","Flutter (Dart)","Android, iOS and Web from one codebase. 22 routes, Material 3 dark and light themes.", (C 30 40 60)),
  @("💾","Backend","Supabase","Auth · PostgreSQL + PostGIS · Storage · Realtime · Edge Functions, via one service layer.", (C 26 44 40)),
  @("🌐","External","OSM · OSRM · Claude","Map tiles, real per-mode routing and the Claude AI guide - keyless where possible.", (C 44 38 22))
)
$cw=270;$ch=270;$sx=60;$sy=160;$gp=15
for($i=0;$i -lt 3;$i++){
    $x=$sx+$i*($cw+$gp)
    Card $s $x $sy $cw $ch $layers[$i][4] $Border | Out-Null
    IconDisc $s ($x+($cw/2)-30) ($sy+22) 60 $layers[$i][0] (C 40 34 14) | Out-Null
    Txt $s $x ($sy+92) $cw 18 $layers[$i][1] 12 $Gold $Fsemi $true $AC $VT | Out-Null
    Txt $s $x ($sy+112) $cw 26 $layers[$i][2] 18 $White $Fhead $true $AC $VT | Out-Null
    Txt $s ($x+18) ($sy+148) ($cw-36) 110 $layers[$i][3] 12.5 $Muted $Fbody $false $AC $VT | Out-Null
    if($i -lt 2){ $ar=$s.Shapes.AddShape($ARROW,($x+$cw+1),($sy+($ch/2)-12),($gp+12),24); $ar.Line.Visible=0; $ar.Fill.Solid(); $ar.Fill.ForeColor.RGB=$Gold; Shadow $ar 6 0 3 0.5 }
}
Footer $s "Behind the story"

# =====================================================================
#  S14 — BY THE NUMBERS
# =====================================================================
$s = New-Slide
Glow $s 520 -130 600 $Gold 88 | Out-Null
Header $s "BEHIND THE STORY  ·  PROOF" "Not a Prototype. A Working Product."
$stats = @(
  @("3","Platforms - Android, iOS & Web"),
  @("22","Navigation routes in the app"),
  @("12","Supabase database tables"),
  @("4","Public storage buckets"),
  @("6","Custom onboarding illustrations"),
  @("100%","Shared cross-platform code")
)
$cw=276;$ch=132;$sx=60;$sy=150;$hx=18;$hy=18
for($i=0;$i -lt 6;$i++){
    $col=$i%3;$row=[int]([math]::Floor($i/3))
    $x=$sx+$col*($cw+$hx);$y=$sy+$row*($ch+$hy)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    $num=Txt $s $x ($y+16) $cw 60 $stats[$i][0] 50 $Gold $Fhead $true $AC $VM
    try { $num.ThreeD.Visible=-1; $num.ThreeD.BevelTopType=8; $num.ThreeD.BevelTopInset=4; $num.ThreeD.Depth=8; $num.ThreeD.ExtrusionColorType=2; $num.ThreeD.ExtrusionColor.RGB=$GoldDeep } catch {}
    Txt $s ($x+14) ($y+84) ($cw-28) 40 $stats[$i][1] 13 $White $Fbody $false $AC $VT | Out-Null
}
Footer $s "Behind the story"

# =====================================================================
#  S15 — IT'S LIVE + WHAT'S NEXT
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Green 90 | Out-Null
Header $s "REAL & SHIPPED" "Amara Is Fictional. The App Is Live."
$ship = @(
  @("🚀","Live on the web","welcome2gh.vercel.app - auto-deploys from GitHub in under a minute."),
  @("📦","Truly cross-platform","One codebase ships an Android APK, an iOS build and a hosted web app."),
  @("⚙️","One-command deploy","A single script runs analyze, tests and the web build, then pushes."),
  @("🧪","Tested foundations","Unit tests cover the geo-math and marker-layout core of the map.")
)
$cw=400;$ch=104;$gx=60;$gy=150;$ax=40;$ay=16
for($i=0;$i -lt 4;$i++){
    $col=$i%2;$row=[int]([math]::Floor($i/2))
    $x=$gx+$col*($cw+$ax);$y=$gy+$row*($ch+$ay)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+20) ($y+22) 52 $ship[$i][0] (C 22 40 26) | Out-Null
    Txt $s ($x+88) ($y+16) ($cw-108) 24 $ship[$i][1] 16 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+88) ($y+44) ($cw-108) 48 $ship[$i][2] 12.5 $Muted $Fbody $false $AL $VT | Out-Null
}
$nx = Card $s 60 398 840 56 $Card $Border
Txt $s 84 398 820 56 "WHAT'S NEXT:  Google OAuth  ·  deploy the AI guide  ·  secure the admin secret  ·  push notifications  ·  real-device QA" 13 $Gold $Fsemi $false $AL $VM | Out-Null
Footer $s "Real & shipped"

# =====================================================================
#  S16 — THANK YOU
# =====================================================================
$s = New-Slide
Glow $s 480 -140 700 $Gold 86 | Out-Null
Glow $s -180 320 540 $Blue 90 | Out-Null
$logo2 = $s.Shapes.AddPicture((Join-Path $root "assets\images\logo.png"),0,-1,440,64,80,77); Shadow $logo2 18 0 8 0.4
Hero3D $s 80 165 800 96 "Akwaaba - Thank You" 56 210 | Out-Null
Txt $s 130 280 700 28 "Every newcomer deserves to feel at home." 18 $White $Fsemi $false $AC $VM | Out-Null
$cc = Card $s 280 335 400 70 $Card $Border
Txt $s 300 343 360 22 "Mohamed  ·  WIUC, Accra" 16 $White $Fsemi $true $AC $VT | Out-Null
Txt $s 300 368 360 18 "welcome2gh.vercel.app" 13 $Gold $Fbody $false $AC $VT | Out-Null
Txt $s 80 430 800 30 "Questions?" 22 $Gold $Fsemi $true $AC $VM | Out-Null

# =====================================================================
#  Transitions (Morph) + save + QA export
# =====================================================================
foreach($sl in $pres.Slides){
    try { $sl.SlideShowTransition.EntryEffect = 3935; $sl.SlideShowTransition.Duration = 1.0; $sl.SlideShowTransition.AdvanceOnClick = -1 } catch {}
}
$pres.SaveAs($pptxPath, 24)
Write-Output ("SAVED: " + $pptxPath + "  (slides: " + $pres.Slides.Count + ")")
Get-ChildItem $qaDir -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -Force
Start-Sleep -Milliseconds 1500
foreach($sl in $pres.Slides){
    $idx = "{0:D2}" -f $sl.SlideIndex
    $done=$false; $try=0
    while(-not $done -and $try -lt 8){
        try { $sl.Export((Join-Path $qaDir ("slide-$idx.png")),"PNG",1280,720); $done=$true } catch { $try++; Start-Sleep -Milliseconds 700 }
    }
}
Write-Output ("EXPORTED QA PNGs")
$pres.Close(); $pp.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pp)   | Out-Null
[GC]::Collect(); [GC]::WaitForPendingFinalizers()
Write-Output "DONE"
