# ============================================================
#  Welcome2GH - University Defense Deck (Bold 3D)
#  Built via PowerPoint COM automation -> native 3D, fully compatible
# ============================================================
$ErrorActionPreference = 'Stop'
$root   = "C:\Users\Mohamed\Desktop\App W2G"
$outDir = Join-Path $root "presentation"
$qaDir  = Join-Path $outDir "qa"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $qaDir  | Out-Null
$pptxPath = Join-Path $outDir "Welcome2GH_Presentation.pptx"
if (Test-Path $pptxPath) { Remove-Item $pptxPath -Force }

# ---- palette (RGB ints: R + G*256 + B*65536) ----
function C($r,$g,$b){ [int]($r + $g*256 + $b*65536) }
$Navy     = C 13 27 42
$NavyTop  = C 22 38 58
$NavyDeep = C 6 13 22
$Card     = C 26 37 53
$CardLite = C 33 47 67
$Gold     = C 255 204 0
$GoldDeep = C 196 150 8
$White    = C 245 247 250
$Muted    = C 150 166 188
$Border   = C 40 54 76
$Green    = C 67 160 71
$Red      = C 229 57 53
$Blue     = C 64 132 240
$Black    = C 0 0 0

$Fhead = "Segoe UI Black"
$Fsemi = "Segoe UI Semibold"
$Fbody = "Segoe UI"
$Femoji= "Segoe UI Emoji"

# shape type constants
$RECT=1; $ROUND=5; $OVAL=9; $ARROW=33
# alignment
$AL=1; $AC=2; $AR=3
# vertical anchor
$VT=1; $VM=3; $VB=4

$pp = New-Object -ComObject PowerPoint.Application
$pp.DisplayAlerts = 1   # ppAlertsNone
try { $pp.Visible = -1 } catch {}
$pres = $pp.Presentations.Add(-1)
# 16:9 widescreen canvas in points (960 x 540)
$pres.PageSetup.SlideWidth  = 960
$pres.PageSetup.SlideHeight = 540
$SW = 960; $SH = 540
try { foreach($w in $pp.Windows){ $w.WindowState = 2 } } catch {}

# ---------- helpers ----------
function New-Slide {
    $s = $pres.Slides.Add($pres.Slides.Count + 1, 12)  # ppLayoutBlank
    $s.FollowMasterBackground = 0
    $s.Background.Fill.Visible = -1
    $s.Background.Fill.TwoColorGradient(4,1)            # diagonal down
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
        $shp.Shadow.Visible = -1
        $shp.Shadow.Style = 1
        $shp.Shadow.ForeColor.RGB = 0
        $shp.Shadow.Blur = $blur
        $shp.Shadow.OffsetX = $ox
        $shp.Shadow.OffsetY = $oy
        $shp.Shadow.Transparency = $tr
    } catch {}
}

function Bevel($shp,$depth,$extCol,$btype,$inset){
    try {
        $shp.ThreeD.Visible = -1
        $shp.ThreeD.BevelTopType = $btype
        $shp.ThreeD.BevelTopInset = $inset
        $shp.ThreeD.BevelTopDepth = 4
        if($depth -gt 0){
            $shp.ThreeD.Depth = $depth
            $shp.ThreeD.ExtrusionColorType = 2
            $shp.ThreeD.ExtrusionColor.RGB = $extCol
        }
    } catch {}
}

function Tilt($shp,$rx,$ry){
    try {
        $shp.ThreeD.Visible = -1
        $shp.ThreeD.RotationX = $rx
        $shp.ThreeD.RotationY = $ry
        $shp.ThreeD.FieldOfView = 40
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
    $tb.TextFrame.MarginLeft=0; $tb.TextFrame.MarginRight=0
    $tb.TextFrame.MarginTop=0;  $tb.TextFrame.MarginBottom=0
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

# small reusable: section title + kicker at top of a content slide
function Header($s,$kicker,$title){
    $bar = $s.Shapes.AddShape($script:ROUND,60,44,8,40)
    try { $bar.Adjustments.Item(1)=0.5 } catch {}
    $bar.Line.Visible=0; $bar.Fill.Solid(); $bar.Fill.ForeColor.RGB=$script:Gold
    Bevel $bar 6 $script:GoldDeep 8 4
    Txt $s 80 40 800 22 $kicker 13 $script:Gold $script:Fsemi $true $AL $VT | Out-Null
    Txt $s 79 58 820 40 $title 30 $script:White $script:Fhead $true $AL $VT | Out-Null
}

function Footer($s,$n){
    Txt $s 60 512 300 18 "Welcome2GH" 10 $script:Muted $script:Fbody $false $AL $VM | Out-Null
    Txt $s 660 512 240 18 ("Akwaaba  ·  " + $n) 10 $script:Gold $script:Fbody $false $AR $VM | Out-Null
}

# emoji icon inside a gold-ish disc
function IconDisc($s,$x,$y,$d,$emoji,$discCol){
    $disc = $s.Shapes.AddShape($script:OVAL,$x,$y,$d,$d)
    $disc.Line.Visible=0; $disc.Fill.Solid(); $disc.Fill.ForeColor.RGB=$discCol
    Shadow $disc 8 0 4 0.5
    Bevel $disc 4 ([int]($discCol-0x101010)) 8 4
    Txt $s $x ($y+1) $d $d $emoji ([int]($d*0.52)) $script:White $script:Femoji $false $AC $VM | Out-Null
    return $disc
}

# framed 3D phone from a screenshot (1080x2400 -> 0.45 ratio)
function Phone($s,$cx,$cy,$targetH,$imgRel,$ry){
    $imgPath = Join-Path $script:root $imgRel
    $w = [double]($targetH * 0.45)
    $x = $cx - $w/2.0
    $y = $cy - $targetH/2.0
    $frame = $s.Shapes.AddShape($script:ROUND,($x-7),($y-7),($w+14),($targetH+14))
    try { $frame.Adjustments.Item(1)=0.13 } catch {}
    $frame.Fill.Solid(); $frame.Fill.ForeColor.RGB = (C 8 12 18)
    $frame.Line.Visible=-1; $frame.Line.ForeColor.RGB=$script:Gold; $frame.Line.Weight=1.5
    Shadow $frame 26 0 16 0.45
    $pic = $s.Shapes.AddPicture($imgPath,0,-1,$x,$y,$w,$targetH)
    $nm1 = "phf_$($s.SlideIndex)"; $nm2 = "php_$($s.SlideIndex)"
    $frame.Name=$nm1; $pic.Name=$nm2
    try {
        $grp = $s.Shapes.Range(@($nm1,$nm2)).Group()
        $grp.ThreeD.Visible=-1
        $grp.ThreeD.RotationY=$ry
        $grp.ThreeD.RotationX=-4
        $grp.ThreeD.FieldOfView=38
        return $grp
    } catch { return $frame }
}

# bullet list block (array of strings)
function Bullets($s,$x,$y,$w,$h,$items,$size,$color){
    $tb = $s.Shapes.AddTextbox(1,$x,$y,$w,$h)
    $tb.TextFrame.WordWrap=-1
    try { $tb.TextFrame.AutoSize=0 } catch {}
    $tb.TextFrame.MarginLeft=0;$tb.TextFrame.MarginRight=0;$tb.TextFrame.MarginTop=0;$tb.TextFrame.MarginBottom=0
    $tr = $tb.TextFrame.TextRange
    $tr.Text = ($items -join "`r")
    $tr.Font.Size=$size; $tr.Font.Name=$script:Fbody; $tr.Font.Color.RGB=$color
    $tr.ParagraphFormat.Alignment=$AL
    try {
        $tr.ParagraphFormat.Bullet.Visible=-1
        $tr.ParagraphFormat.Bullet.Character=8226
        $tr.ParagraphFormat.Bullet.Font.Color.RGB=$script:Gold
        $tr.ParagraphFormat.SpaceAfter=10
        $tr.ParagraphFormat.SpaceBefore=0
    } catch {}
    return $tb
}

# =====================================================================
#  SLIDE 1 — TITLE
# =====================================================================
$s = New-Slide
Glow $s 520 -120 620 $Gold 88 | Out-Null
Glow $s -160 300 520 $Blue 90 | Out-Null
# logo
$logo = $s.Shapes.AddPicture((Join-Path $root "assets\images\logo.png"),0,-1,440,52,80,77)
Shadow $logo 18 0 8 0.4
# 3D title
$t = Txt $s 80 150 800 110 "Welcome2GH" 76 $Gold $Fhead $true $AC $VM
try {
    $t.Line.Visible=0
    $t.TextFrame.WordWrap=0
    $t.TextFrame.AutoSize=1
    $t.Top = 205 - $t.Height/2.0
    $t.Left = (960 - $t.Width)/2.0
    $t.Fill.Visible=0
    $t.ThreeD.Visible=-1; $t.ThreeD.BevelTopType=8; $t.ThreeD.BevelTopInset=6
    $t.ThreeD.Depth=14; $t.ThreeD.ExtrusionColorType=2; $t.ThreeD.ExtrusionColor.RGB=$GoldDeep
} catch {}
Txt $s 130 270 700 34 "Smart Tourism & Student Assistance for Accra, Ghana" 20 $White $Fsemi $false $AC $VM | Out-Null
# pills
$pillTexts = @("Flutter","Supabase","PostGIS Maps","Claude AI")
$px = 270
foreach($pt in $pillTexts){
    $pw = 12 + $pt.Length*9
    $pill = $s.Shapes.AddShape($ROUND,$px,322,$pw,30)
    try { $pill.Adjustments.Item(1)=0.5 } catch {}
    $pill.Line.Visible=-1; $pill.Line.ForeColor.RGB=$Border; $pill.Line.Weight=1
    $pill.Fill.Solid(); $pill.Fill.ForeColor.RGB=$Card
    Shadow $pill 6 0 3 0.6
    Txt $s $px 322 $pw 30 $pt 12 $Gold $Fsemi $true $AC $VM | Out-Null
    $px += $pw + 12
}
# presenter card
$pc = Card $s 230 392 500 64 $Card $Border
Txt $s 250 400 460 20 "Mohamed" 16 $White $Fsemi $true $AC $VT | Out-Null
Txt $s 250 424 460 18 "Wisconsin International University College (WIUC)  ·  Accra, 2026" 12 $Muted $Fbody $false $AC $VT | Out-Null
Txt $s 80 474 800 22 "LIVE  ·  welcome2gh.vercel.app" 13 $Gold $Fsemi $true $AC $VM | Out-Null

# =====================================================================
#  SLIDE 2 — THE PROBLEM
# =====================================================================
$s = New-Slide
Glow $s 640 -140 520 $Red 90 | Out-Null
Header $s "THE CHALLENGE" "Arriving in Accra Is Harder Than It Should Be"
$probs = @(
  @("🧭","Hard to Navigate","Unfamiliar streets and unreliable directions leave newcomers lost and dependent on others."),
  @("💸","Overpriced as a Visitor","With no fixed prices, tourists and students are routinely charged far above the fair rate."),
  @("⚠️","Safety Uncertainty","No way to know which areas to avoid — and no real-time alerts when something changes."),
  @("🌍","No Local Knowledge","Language gaps and missing local insight make everyday choices stressful and risky.")
)
$cardW=400; $cardH=128; $gx=60; $gy=130; $gapX=40; $gapY=22
for($i=0;$i -lt 4;$i++){
    $col = $i % 2; $row = [int]([math]::Floor($i/2))
    $x = $gx + $col*($cardW+$gapX)
    $y = $gy + $row*($cardH+$gapY)
    Card $s $x $y $cardW $cardH $Card $Border | Out-Null
    IconDisc $s ($x+22) ($y+24) 56 $probs[$i][0] (C 38 30 30) | Out-Null
    Txt $s ($x+96) ($y+22) ($cardW-118) 26 $probs[$i][1] 17 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+96) ($y+52) ($cardW-118) 64 $probs[$i][2] 12.5 $Muted $Fbody $false $AL $VT | Out-Null
}
Footer $s "Problem"

# =====================================================================
#  SLIDE 3 — THE SOLUTION
# =====================================================================
$s = New-Slide
Glow $s 700 -120 560 $Gold 88 | Out-Null
Header $s "THE SOLUTION" "One App. Everything a Newcomer Needs."
Phone $s 770 320 360 "_emu_login.png" -22 | Out-Null
$sols = @(
  @("🗺️","Navigate with confidence","Live maps and true turn-by-turn directions tuned for Accra."),
  @("💰","Always pay a fair price","Community-verified prices end the guesswork and the overcharging."),
  @("👥","Belong from day one","A local community, reviews, and a Claude-powered AI guide in your pocket.")
)
$y=150
foreach($sol in $sols){
    Card $s 60 $y 520 96 $Card $Border | Out-Null
    IconDisc $s 80 ($y+22) 52 $sol[0] (C 40 34 14) | Out-Null
    Txt $s 150 ($y+18) 410 24 $sol[1] 17 $Gold $Fsemi $true $AL $VT | Out-Null
    Txt $s 150 ($y+46) 410 40 $sol[2] 13 $White $Fbody $false $AL $VT | Out-Null
    $y += 112
}
Footer $s "Solution"

# =====================================================================
#  SLIDE 4 — KEY FEATURES (6 cards)
# =====================================================================
$s = New-Slide
Glow $s -140 -120 480 $Blue 90 | Out-Null
Glow $s 760 360 460 $Gold 91 | Out-Null
Header $s "PRODUCT" "Six Features That Work Together"
$feats = @(
  @("📍","Live Map","OpenStreetMap with clustering, alert zones and GPS follow mode."),
  @("🧭","Smart Directions","OSRM routing with real per-mode times and turn-by-turn nav."),
  @("💰","Fair Price","Community price reports plus verified, trustworthy rates."),
  @("👥","Community","Realtime posts, likes, comments and photo reviews."),
  @("🤖","AI Assistant","A Claude-powered local guide for tips, safety and culture."),
  @("⚠️","Safety Alerts","Danger zones drawn with a real radius and auto-expiry.")
)
$cw=276; $ch=150; $sx=60; $sy=128; $hx=18; $hy=18
for($i=0;$i -lt 6;$i++){
    $col=$i%3; $row=[int]([math]::Floor($i/3))
    $x=$sx+$col*($cw+$hx); $y=$sy+$row*($ch+$hy)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+20) ($y+20) 54 $feats[$i][0] (C 40 34 14) | Out-Null
    Txt $s ($x+20) ($y+84) ($cw-40) 24 $feats[$i][1] 17 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+20) ($y+110) ($cw-40) 36 $feats[$i][2] 11.5 $Muted $Fbody $false $AL $VT | Out-Null
}
Footer $s "Features"

# =====================================================================
#  SLIDE 5 — NAVIGATION DEEP DIVE
# =====================================================================
$s = New-Slide
Glow $s -160 300 520 $Blue 90 | Out-Null
Header $s "DEEP DIVE  ·  MAPS" "Real-Time Navigation, Built From Scratch"
Phone $s 195 322 360 "_emu_shot2.png" 22 | Out-Null
Bullets $s 400 150 500 300 @(
  "OpenStreetMap (Carto Voyager tiles) — no API key required",
  "OSRM routing with real car / bike / foot travel times",
  "Google-Maps-style live GPS dot: pulsing sonar ring + heading cone",
  "Custom priority-based marker decluttering (no plugin clustering)",
  "PostGIS nearby_places & nearby_alerts geo-search on the backend",
  "Unidirectional map state with unit-tested Web-Mercator geo math"
) 15 $White | Out-Null
Footer $s "Navigation"

# =====================================================================
#  SLIDE 6 — FAIR PRICE
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Gold 89 | Out-Null
Header $s "DEEP DIVE  ·  TRUST" "Ending the 'Visitor Tax'"
# before / after comparison
$bx=60; $by=140; $bw=400; $bh=300
$bad = Card $s $bx $by $bw $bh (C 42 26 26) (C 90 50 50)
Txt $s ($bx+24) ($by+22) ($bw-48) 26 "❌  Without Welcome2GH" 17 (C 255 138 138) $Fsemi $true $AL $VT | Out-Null
Bullets $s ($bx+24) ($by+62) ($bw-48) 210 @(
  "No reference for what things actually cost",
  "Charged 2–5x the local price",
  "No way to verify a 'fair' quote",
  "Easy target for scams and pressure"
) 14 $White | Out-Null
$gx2=500
$good = Card $s $gx2 $by $bw $bh (C 22 40 26) (C 50 92 56)
Txt $s ($gx2+24) ($by+22) ($bw-48) 26 "✓  With Welcome2GH" 17 (C 138 230 150) $Fsemi $true $AL $VT | Out-Null
Bullets $s ($gx2+24) ($by+62) ($bw-48) 210 @(
  "Community submits real prices for goods & services",
  "Verified prices surface the trustworthy rate",
  "Negotiate from facts, not guesses",
  "Confidence to shop, ride and explore freely"
) 14 $White | Out-Null
Footer $s "Fair Price"

# =====================================================================
#  SLIDE 7 — AI ASSISTANT
# =====================================================================
$s = New-Slide
Glow $s -140 -130 500 $Blue 90 | Out-Null
Glow $s 720 340 460 $Gold 91 | Out-Null
Header $s "DEEP DIVE  ·  AI" "An AI Local Guide, Powered by Claude"
$big = IconDisc $s 120 200 150 "🤖" (C 36 30 14)
Bullets $s 330 168 560 260 @(
  "Claude API served securely through a Supabase Edge Function (ai-guide)",
  "Chat-based guidance: recommendations, directions, safety and culture",
  "Speaks with a warm Ghanaian 'Akwaaba' tone — welcoming, not robotic",
  "Keeps secrets on the backend — no API keys ever shipped in the app"
) 15 $White | Out-Null
$quote = Card $s 60 432 840 70 $Card $Border
Txt $s 84 444 800 46 '"Where can I find authentic, fairly-priced jollof near Osu - and is it safe to walk there tonight?"' 15 $Gold "Segoe UI Semilight" $false $AL $VM | Out-Null
Footer $s "AI Assistant"

# =====================================================================
#  SLIDE 8 — COMMUNITY
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Gold 89 | Out-Null
Header $s "DEEP DIVE  ·  COMMUNITY" "Trust Grows From the Community"
$comm = @(
  @("⚡","Realtime Feed","Posts stream in live via Supabase Realtime — always current."),
  @("❤️","Likes & Comments","Lightweight social layer so locals and visitors engage."),
  @("⭐","Photo Reviews","Rate and review places with real photos in Supabase Storage."),
  @("📍","User-Added Places","The map grows from the community, with admin moderation.")
)
$cw=400;$ch=120;$gx=60;$gy=135;$ax=40;$ay=20
for($i=0;$i -lt 4;$i++){
    $col=$i%2;$row=[int]([math]::Floor($i/2))
    $x=$gx+$col*($cw+$ax);$y=$gy+$row*($ch+$ay)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+22) ($y+22) 52 $comm[$i][0] (C 40 34 14) | Out-Null
    Txt $s ($x+92) ($y+20) ($cw-112) 24 $comm[$i][1] 16 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+92) ($y+48) ($cw-112) 56 $comm[$i][2] 12.5 $Muted $Fbody $false $AL $VT | Out-Null
}
Footer $s "Community"

# =====================================================================
#  SLIDE 9 — ARCHITECTURE
# =====================================================================
$s = New-Slide
Glow $s -160 320 520 $Blue 91 | Out-Null
Header $s "ENGINEERING" "A Clean, Modern Architecture"
# three layered columns
$layers = @(
  @("📱","Frontend","Flutter (Dart)","Android · iOS · Web from one codebase. go_router (22 routes), Material 3 dark/light themes.", (C 30 40 60)),
  @("💾","Backend","Supabase","Auth · PostgreSQL + PostGIS · Storage · Realtime · Edge Functions. All calls via one SupabaseService.", (C 26 44 40)),
  @("🌐","External APIs","OSM · OSRM · Claude","Map tiles, real per-mode routing, and the Claude AI guide — keyless where possible.", (C 44 38 22))
)
$cw=270;$ch=290;$sx=60;$sy=140;$gap=15
for($i=0;$i -lt 3;$i++){
    $x=$sx+$i*($cw+$gap)
    Card $s $x $sy $cw $ch $layers[$i][4] $Border | Out-Null
    IconDisc $s ($x+($cw/2)-32) ($sy+24) 64 $layers[$i][0] (C 40 34 14) | Out-Null
    Txt $s $x ($sy+96) $cw 18 $layers[$i][1] 12 $Gold $Fsemi $true $AC $VT | Out-Null
    Txt $s $x ($sy+116) $cw 26 $layers[$i][2] 19 $White $Fhead $true $AC $VT | Out-Null
    Txt $s ($x+18) ($sy+154) ($cw-36) 120 $layers[$i][3] 12.5 $Muted $Fbody $false $AC $VT | Out-Null
    if($i -lt 2){
        $ar = $s.Shapes.AddShape($ARROW,($x+$cw+1),($sy+($ch/2)-12),($gap+12),24)
        $ar.Line.Visible=0; $ar.Fill.Solid(); $ar.Fill.ForeColor.RGB=$Gold
        Shadow $ar 6 0 3 0.5
    }
}
Footer $s "Architecture"

# =====================================================================
#  SLIDE 10 — BY THE NUMBERS
# =====================================================================
$s = New-Slide
Glow $s 520 -130 600 $Gold 88 | Out-Null
Header $s "BY THE NUMBERS" "One Codebase, Real Depth"
$stats = @(
  @("3","Platforms — Android, iOS & Web"),
  @("22","Navigation routes in the app"),
  @("12","Supabase database tables"),
  @("4","Public storage buckets"),
  @("6","Custom onboarding illustrations"),
  @("100%","Shared cross-platform code")
)
$cw=276;$ch=140;$sx=60;$sy=140;$hx=18;$hy=18
for($i=0;$i -lt 6;$i++){
    $col=$i%3;$row=[int]([math]::Floor($i/3))
    $x=$sx+$col*($cw+$hx);$y=$sy+$row*($ch+$hy)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    $num = Txt $s $x ($y+18) $cw 64 $stats[$i][0] 52 $Gold $Fhead $true $AC $VM
    try { $num.ThreeD.Visible=-1; $num.ThreeD.BevelTopType=8; $num.ThreeD.BevelTopInset=4; $num.ThreeD.Depth=8; $num.ThreeD.ExtrusionColorType=2; $num.ThreeD.ExtrusionColor.RGB=$GoldDeep; $num.ThreeD.PresetMaterial=4 } catch {}
    Txt $s ($x+14) ($y+90) ($cw-28) 40 $stats[$i][1] 13 $White $Fbody $false $AC $VT | Out-Null
}
Footer $s "Metrics"

# =====================================================================
#  SLIDE 11 — DESIGN & IDENTITY
# =====================================================================
$s = New-Slide
Glow $s -150 -120 500 $Gold 90 | Out-Null
Header $s "DESIGN" "A Visual Identity Rooted in Ghana"
Bullets $s 60 150 470 300 @(
  "Dark navy + gold palette inspired by the Ghana flag",
  "Glassmorphism cards with a consistent 16px radius",
  "Adinkra star motifs and an 'Akwaaba' welcome greeting",
  "Full dark / light theming via dynamic AppColors getters",
  "Barlow display headings paired with Inter body text",
  "Custom logo with a soft gold glow, no flat white circle"
) 15 $White | Out-Null
# swatches
$swatch = @( @("Navy",(C 13 27 42)), @("Card",(C 26 37 53)), @("Gold",$Gold), @("Success",$Green), @("Danger",$Red) )
$sx=560;$sy=150
for($i=0;$i -lt 5;$i++){
    $y=$sy+$i*54
    $sw = Card $s $sx $y 300 44 $swatch[$i][1] $Border
    Txt $s ($sx+16) $y 200 44 $swatch[$i][0] 14 $White $Fsemi $true $AL $VM | Out-Null
}
Footer $s "Design"

# =====================================================================
#  SLIDE 12 — LIVE & DEPLOYED
# =====================================================================
$s = New-Slide
Glow $s 700 -120 520 $Green 90 | Out-Null
Header $s "SHIPPED" "Live, Deployed and Cross-Platform"
$ship = @(
  @("🚀","Live on the Web","welcome2gh.vercel.app — auto-deploys from GitHub main in under a minute."),
  @("⚙️","One-Command Deploy","A single script runs analyze + tests + web build, then commits and pushes."),
  @("📦","Truly Cross-Platform","Ships as an Android APK, an iOS build and a hosted web app from one codebase."),
  @("🧪","Tested Foundations","Unit tests cover the geo-math and marker-layout core of the map engine.")
)
$cw=400;$ch=120;$gx=60;$gy=135;$ax=40;$ay=20
for($i=0;$i -lt 4;$i++){
    $col=$i%2;$row=[int]([math]::Floor($i/2))
    $x=$gx+$col*($cw+$ax);$y=$gy+$row*($ch+$ay)
    Card $s $x $y $cw $ch $Card $Border | Out-Null
    IconDisc $s ($x+22) ($y+22) 52 $ship[$i][0] (C 22 40 26) | Out-Null
    Txt $s ($x+92) ($y+20) ($cw-112) 24 $ship[$i][1] 16 $White $Fsemi $true $AL $VT | Out-Null
    Txt $s ($x+92) ($y+48) ($cw-112) 56 $ship[$i][2] 12.5 $Muted $Fbody $false $AL $VT | Out-Null
}
Footer $s "Deployment"

# =====================================================================
#  SLIDE 13 — ROADMAP
# =====================================================================
$s = New-Slide
Glow $s -150 320 500 $Blue 91 | Out-Null
Header $s "WHAT'S NEXT" "The Road to Public Launch"
$road = @(
  @("Enable Google OAuth in Supabase (Client ID + Secret from GCP)"),
  @("Deploy the AI guide Edge Function with the production API key"),
  @("Move the admin access secret from the client to the backend"),
  @("Wire up push notifications (settings UI already in place)"),
  @("Real-device QA on a range of Android hardware")
)
$y=150
for($i=0;$i -lt 5;$i++){
    Card $s 60 $y 840 56 $Card $Border | Out-Null
    $n = IconDisc $s 78 ($y+10) 36 (($i+1).ToString()) (C 40 34 14)
    Txt $s 138 $y 740 56 $road[$i][0] 15 $White $Fbody $false $AL $VM | Out-Null
    $y += 68
}
Footer $s "Roadmap"

# =====================================================================
#  SLIDE 14 — THANK YOU
# =====================================================================
$s = New-Slide
Glow $s 480 -140 700 $Gold 86 | Out-Null
Glow $s -180 320 540 $Blue 90 | Out-Null
$logo2 = $s.Shapes.AddPicture((Join-Path $root "assets\images\logo.png"),0,-1,440,70,80,77)
Shadow $logo2 18 0 8 0.4
$ty = Txt $s 80 175 800 96 "Akwaaba — Thank You" 60 $Gold $Fhead $true $AC $VM
try {
    $ty.Line.Visible=0
    $ty.TextFrame.WordWrap=0
    $ty.TextFrame.AutoSize=1
    $ty.Top = 223 - $ty.Height/2.0
    $ty.Left = (960 - $ty.Width)/2.0
    $ty.Fill.Visible=0
    $ty.ThreeD.Visible=-1; $ty.ThreeD.BevelTopType=8; $ty.ThreeD.BevelTopInset=6; $ty.ThreeD.Depth=12
    $ty.ThreeD.ExtrusionColorType=2; $ty.ThreeD.ExtrusionColor.RGB=$GoldDeep
} catch {}
Txt $s 130 285 700 28 "Smart tourism & student assistance for Accra, Ghana" 17 $White $Fsemi $false $AC $VM | Out-Null
$cc = Card $s 280 345 400 70 $Card $Border
Txt $s 300 353 360 22 "Mohamed  ·  WIUC, Accra" 16 $White $Fsemi $true $AC $VT | Out-Null
Txt $s 300 378 360 18 "welcome2gh.vercel.app" 13 $Gold $Fbody $false $AC $VT | Out-Null
Txt $s 80 440 800 30 "Questions?" 22 $Gold $Fsemi $true $AC $VM | Out-Null

# =====================================================================
#  Transitions (3D / dynamic) — applied to every slide, best-effort
# =====================================================================
$ppTransMorph = 3935
foreach($sl in $pres.Slides){
    try {
        $sl.SlideShowTransition.EntryEffect = $ppTransMorph
        $sl.SlideShowTransition.Duration = 1.0
        $sl.SlideShowTransition.AdvanceOnClick = -1
    } catch {}
}

# ---- save as pptx ----
$pres.SaveAs($pptxPath, 24)   # ppSaveAsOpenXMLPresentation
Write-Output ("SAVED: " + $pptxPath + "  (slides: " + $pres.Slides.Count + ")")

# ---- export QA pngs ----
Get-ChildItem $qaDir -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -Force
Start-Sleep -Milliseconds 1500
foreach($sl in $pres.Slides){
    $idx = "{0:D2}" -f $sl.SlideIndex
    $done=$false; $try=0
    while(-not $done -and $try -lt 8){
        try { $sl.Export((Join-Path $qaDir ("slide-$idx.png")),"PNG",1280,720); $done=$true }
        catch { $try++; Start-Sleep -Milliseconds 700 }
    }
}
Write-Output ("EXPORTED QA PNGs to " + $qaDir)

$pres.Close()
$pp.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pp)   | Out-Null
[GC]::Collect(); [GC]::WaitForPendingFinalizers()
Write-Output "DONE"
