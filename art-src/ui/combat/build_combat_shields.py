"""Author the original vector battle crests and matching editable SVG masters."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MASTER = Path(__file__).resolve().parent
RUNTIME = ROOT / "assets" / "ui" / "combat"
RUNTIME.mkdir(parents=True, exist_ok=True)

OUTLINE = "M128 18 L223 35 C223 106 219 181 179 222 Q154 250 128 266 Q100 252 76 226 C36 188 33 111 33 35 Z"
INNER = "M128 34 L206 49 C205 116 199 174 165 212 Q144 235 128 246 Q110 235 91 214 C57 181 50 121 50 49 Z"


def definitions(team):
    palette = {
        "blue": ("#315da5", "#163e79", "#0c2451", "#4788d1", "#102a55"),
        "red": ("#d34230", "#9a211d", "#531211", "#ed6951", "#6d1716"),
    }
    top, middle, bottom, shine, ribbon = palette[team]
    return f'''<defs>
  <linearGradient id="face" x1="0" y1="0" x2="0.65" y2="1">
    <stop stop-color="{top}"/><stop offset=".4" stop-color="{middle}"/><stop offset="1" stop-color="{bottom}"/>
  </linearGradient>
  <linearGradient id="silk" x1="0" y1="0" x2="0" y2="1">
    <stop stop-color="{shine}"/><stop offset=".48" stop-color="{middle}"/><stop offset="1" stop-color="{ribbon}"/>
  </linearGradient>
  <linearGradient id="rim" x1=".12" y1="0" x2=".8" y2="1">
    <stop stop-color="#fff3b4"/><stop offset=".13" stop-color="#e5b864"/>
    <stop offset=".31" stop-color="#bd7f32"/><stop offset=".57" stop-color="#e3ab48"/>
    <stop offset=".8" stop-color="#9a5d22"/><stop offset="1" stop-color="#efce83"/>
  </linearGradient>
  <linearGradient id="gold" x1=".18" y1="0" x2=".9" y2="1">
    <stop stop-color="#fff1ad"/><stop offset=".26" stop-color="#efca78"/>
    <stop offset=".54" stop-color="#d99838"/><stop offset="1" stop-color="#a86c27"/>
  </linearGradient>
  <linearGradient id="edge" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#fff8ce"/><stop offset=".6" stop-color="#dba544"/><stop offset="1" stop-color="#784519"/>
  </linearGradient>
  <linearGradient id="steel" x1="0" y1=".2" x2="1" y2=".7">
    <stop stop-color="#5d6d83"/><stop offset=".36" stop-color="#d5e4ea"/>
    <stop offset=".55" stop-color="#f6fcfd"/><stop offset=".58" stop-color="#a2b5c8"/><stop offset="1" stop-color="#566677"/>
  </linearGradient>
  <linearGradient id="wood" x1="0" y1="0" x2="1" y2=".2">
    <stop stop-color="#81502b"/><stop offset=".23" stop-color="#d89a52"/>
    <stop offset=".5" stop-color="#e8b46a"/><stop offset=".85" stop-color="#ae7037"/><stop offset="1" stop-color="#724121"/>
  </linearGradient>
  <linearGradient id="shaft" x1="0" y1="0" x2="1" y2="0">
    <stop stop-color="#6b3b18"/><stop offset=".35" stop-color="#f2c773"/><stop offset=".6" stop-color="#cb8c3c"/><stop offset="1" stop-color="#80501d"/>
  </linearGradient>
  <radialGradient id="stone" cx=".28" cy=".22" r=".85">
    <stop stop-color="#faf4e5"/><stop offset=".28" stop-color="#c9c6be"/><stop offset=".72" stop-color="#898f92"/><stop offset="1" stop-color="#4d5863"/>
  </radialGradient>
  <radialGradient id="rivet" cx=".25" cy=".2" r=".85">
    <stop stop-color="#fff7ca"/><stop offset=".5" stop-color="#b88947"/><stop offset="1" stop-color="#503013"/>
  </radialGradient>
</defs>'''


def crest_base():
    return f'''<path d="M37 209 L9 213 L20 236 L10 253 L52 248 L68 230 Z" fill="#0c1724" opacity=".4" transform="translate(1 5)"/>
<path d="M219 209 L247 213 L236 236 L246 253 L204 248 L188 230 Z" fill="#0c1724" opacity=".4" transform="translate(1 5)"/>
<path d="M37 207 L9 211 L20 233 L10 250 L51 245 L68 226 Z M219 207 L247 211 L236 233 L246 250 L205 245 L188 226 Z" fill="url(#silk)" stroke="#c5a35f" stroke-width="1.4"/>
<path d="M11 213 L43 221 L61 223 M245 213 L213 221 L195 223 M14 245 L43 240 M242 245 L213 240" fill="none" stroke="#a7cdf0" stroke-opacity=".32" stroke-width="2"/>
<path d="M37 207 L38 230 L61 236 L68 226 Z M219 207 L218 230 L195 236 L188 226 Z" fill="#0b162b" opacity=".66"/>
<path d="{OUTLINE}" fill="#0b1018" opacity=".52" transform="translate(3 8)"/>
<path d="{OUTLINE}" fill="url(#rim)" stroke="#57371d" stroke-width="3"/>
<path d="M128 22 L219 39 C219 115 209 180 176 220 Q150 247 128 261 Q104 248 80 223 C44 189 38 116 37 39 Z" fill="none" stroke="#fff0bd" stroke-width="2.5" opacity=".8"/>
<path d="M128 29 L212 44 C210 117 205 176 170 216 Q147 240 128 253 Q107 241 86 217 C50 182 46 118 45 44 Z" fill="#69421f"/>
<path d="{INNER}" fill="url(#face)" stroke="#f2cf83" stroke-width="1.5"/>
<path d="M128 34 L87 43 L91 214 Q110 235 128 246 Z" fill="#fff" opacity=".035"/>
<path d="M128 34 L163 41 L164 211 Q144 235 128 246 Z" fill="#fff" opacity=".025"/>
<path d="M74 45 L77 193 M103 39 L104 226 M155 40 L153 226 M180 45 L177 195" fill="none" stroke="#080d21" stroke-width="1" opacity=".17"/>
<path d="M50 49 L128 34 L206 49" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="2"/>
<path d="M51 51 C52 119 59 178 91 212 Q109 232 128 244" fill="none" stroke="#8ba6bc" stroke-opacity=".32" stroke-width="1.5"/>
<g fill="url(#rivet)" stroke="#6e4823" stroke-width=".7">
<circle cx="75" cy="34" r="3.4"/><circle cx="180" cy="34" r="3.4"/>
<circle cx="42" cy="91" r="3.2"/><circle cx="214" cy="91" r="3.2"/>
<circle cx="61" cy="190" r="3.2"/><circle cx="195" cy="190" r="3.2"/>
<circle cx="128" cy="256" r="3.2"/></g>'''


def infantry():
    return '''<g transform="translate(1 5)" fill="#091321" opacity=".55">
<path d="M79 215 L134 126 L142 130 L87 220 Z M134 126 L142 130 L163 78 L132 102 Z"/>
<path d="M165 110 C145 116 128 146 128 173 C128 198 140 215 153 219 C176 201 188 171 184 142 C182 126 174 115 165 110 Z"/></g>
<path d="M80 213 L135 124 L143 128 L87 218 Z" fill="url(#shaft)" stroke="#67451d" stroke-width="1.2"/>
<path d="M82 214 L137 126" fill="none" stroke="#fff3b2" stroke-width="1.7" opacity=".8"/>
<path d="M134 127 L131 102 L161 76 L148 115 L141 131 Z" fill="url(#steel)" stroke="#364250" stroke-width="1.2"/>
<path d="M136 124 L161 76 L142 108 Z" fill="#e8f3f6"/>
<path d="M134 125 L142 129 L146 123 L138 119 Z" fill="url(#gold)" stroke="#5d3f21" stroke-width="1"/>
<path d="M166 108 C144 115 128 143 128 170 C128 196 140 213 153 216 C176 198 188 168 184 140 C182 124 175 112 166 108 Z" fill="url(#gold)" stroke="#57391f" stroke-width="2"/>
<path d="M165 113 C147 119 133 144 133 170 C133 193 142 206 153 211 C173 195 183 168 180 141 C178 127 172 118 165 113 Z" fill="url(#wood)" stroke="#f5d898" stroke-width="1.5"/>
<path d="M165 115 L153 210 M157 120 L145 204 M174 129 L163 200 M145 134 L138 190" fill="none" stroke="#6d4222" stroke-width="1.2" opacity=".65"/>
<path d="M165 117 L154 207 M158 122 L147 203 M175 130 L165 197" fill="none" stroke="#ffe3a7" stroke-width=".9" opacity=".4"/>
<path d="M166 111 Q140 126 133 158 Q126 191 153 214" fill="none" stroke="#fff0ad" stroke-width="1.6"/>
<path d="M154 215 Q183 189 184 148" fill="none" stroke="#68411d" stroke-width="1.6"/>
<circle cx="154" cy="128" r="1.5" fill="#654322"/><circle cx="145" cy="191" r="1.5" fill="#654322"/>'''


def crossbow():
    return '''<g transform="translate(2 4)" stroke="#071426" stroke-opacity=".6" stroke-linecap="round" fill="none">
<path d="M79 208 L159 107" stroke-width="15"/><path d="M95 78 Q95 155 181 167" stroke-width="12"/></g>
<path d="M78 203 L157 105 L166 113 L87 212 Z" fill="url(#wood)" stroke="#60411f" stroke-width="2"/>
<path d="M82 203 L158 110" fill="none" stroke="#f4d390" stroke-width="2"/>
<path d="M151 120 L160 126 L171 112 L162 103 Z" fill="url(#gold)" stroke="#62441f" stroke-width="1.5"/>
<path d="M95 77 C96 119 125 163 181 166" fill="none" stroke="#4c2f17" stroke-width="12" stroke-linecap="round"/>
<path d="M95 77 C96 119 125 163 181 166" fill="none" stroke="url(#gold)" stroke-width="8" stroke-linecap="round"/>
<path d="M93 76 Q125 118 181 165" fill="none" stroke="#fff0ad" stroke-width="1.7"/>
<path d="M93 76 L153 109 L181 165" fill="none" stroke="#342c2a" stroke-width="2.4"/>
<path d="M94 77 L153 108 L181 164" fill="none" stroke="#e2d2b0" stroke-width="1"/>
<path d="M108 174 L167 98" fill="none" stroke="#6f3e1d" stroke-width="5"/>
<path d="M107 172 L166 97" fill="none" stroke="#f3e4b3" stroke-width="2.2"/>
<path d="M162 99 L178 82 L171 105 Z" fill="url(#steel)" stroke="#566577" stroke-width="1"/>
<path d="M102 171 L109 176 L104 186 L98 181 Z" fill="#e7dab0" stroke="#5b4027" stroke-width="1"/>
<path d="M89 189 L99 196 L91 206 L81 199 Z" fill="url(#gold)" stroke="#7f5124" stroke-width="1"/>
<path d="M134 140 L142 146 L136 157 L128 151 Z" fill="url(#steel)" stroke="#48505b" stroke-width="1"/>
<circle cx="95" cy="77" r="4" fill="url(#rivet)"/><circle cx="181" cy="166" r="4" fill="url(#rivet)"/>'''


def cavalry():
    return '''<path d="M145 75 L148 57 L156 82 L161 74 L168 92 C181 103 183 119 191 133 L202 150 Q205 160 194 167 L184 168 L178 163 L161 157 Q151 168 145 182 L153 222 Q126 219 98 204 L101 174 L97 172 L106 161 L102 160 L111 147 L106 147 L117 128 L112 128 L126 108 L123 108 L139 92 L132 94 Z" fill="#081426" opacity=".6" transform="translate(3 5)"/>
<path d="M144 77 L147 58 L156 82 L161 73 L168 91 C180 102 182 119 190 133 L201 150 Q204 160 193 166 L183 167 L177 162 L160 156 Q150 167 144 181 L152 219 Q125 218 98 202 L102 173 L97 171 L106 161 L102 160 L111 147 L107 146 L117 128 L112 128 L125 109 L122 108 L139 92 L132 94 Z" fill="url(#gold)" stroke="#5d371d" stroke-width="2.2" stroke-linejoin="round"/>
<path d="M143 83 L146 69 L151 87 L158 86 Q164 98 161 110 Q154 127 158 151 Q142 160 136 180 L142 213 Q122 207 111 199 Q108 165 130 131 Q140 109 138 98 Z" fill="#fff0b1" opacity=".33"/>
<path d="M98 202 Q100 162 121 132 Q137 113 140 94 L135 95 L125 109 L128 109 L115 128 L120 129 L111 147 L116 147 L105 160 L110 161 L101 172 L107 173 L104 200 Z" fill="#986027"/>
<path d="M118 196 Q116 166 131 143 M125 132 Q145 109 143 94" fill="none" stroke="#fbd994" stroke-width="2" stroke-linecap="round" opacity=".65"/>
<path d="M157 82 L149 64 L150 83 M162 78 L161 91" fill="none" stroke="#9b5b27" stroke-width="2"/>
<path d="M166 104 Q176 113 183 129" fill="none" stroke="#fff0b3" stroke-width="3" stroke-linecap="round"/>
<path d="M162 112 Q168 107 173 114" fill="none" stroke="#895422" stroke-width="1.7"/>
<ellipse cx="170" cy="116" rx="4" ry="5" fill="#352316" transform="rotate(-20 170 116)"/>
<circle cx="169" cy="114" r="1.2" fill="#fff2c5"/>
<path d="M183 142 Q185 137 190 141 Q192 145 188 148" fill="#754323"/>
<path d="M194 158 Q185 159 179 154" fill="none" stroke="#754823" stroke-width="1.8" stroke-linecap="round"/>
<path d="M159 157 Q149 165 142 180 L151 216" fill="none" stroke="#8c5522" stroke-width="1.7"/>
<path d="M120 211 Q135 216 152 219" fill="none" stroke="#fff0b1" stroke-width="1.2"/>'''


def siege():
    return '''<g transform="translate(2 5)" fill="#071221" opacity=".7">
<path d="M81 179 L179 179 L183 195 L77 195 Z M106 178 L136 112 L148 117 L119 181 Z M141 115 L174 179 L161 185 L131 121 Z"/>
<circle cx="87" cy="193" r="21"/><circle cx="171" cy="193" r="21"/>
<circle cx="81" cy="82" r="23"/><circle cx="126" cy="66" r="27"/><circle cx="172" cy="82" r="23"/></g>
<path d="M87 178 L140 111 L149 118 L98 184 Z" fill="url(#wood)" stroke="#68411b" stroke-width="2"/>
<path d="M132 116 L145 112 L175 178 L163 185 Z" fill="url(#gold)" stroke="#68411b" stroke-width="2"/>
<path d="M96 184 L146 118 M139 119 L166 179" fill="none" stroke="#ffdfa2" stroke-width="2"/>
<path d="M78 177 L181 177 L181 195 L78 195 Z" fill="url(#gold)" stroke="#57351d" stroke-width="2"/>
<path d="M79 179 L179 179" stroke="#fff0b0" stroke-width="2"/>
<path d="M78 193 L180 193" stroke="#8c5522" stroke-width="2"/>
<path d="M99 167 L166 96 L177 104 L111 177 Z" fill="url(#gold)" stroke="#68411b" stroke-width="2"/>
<path d="M104 168 L169 99" stroke="#fff1b1" stroke-width="2"/>
<path d="M168 100 L181 89 L190 98 Q186 107 177 111 Z" fill="url(#wood)" stroke="#6c431e" stroke-width="2"/>
<path d="M176 95 L184 97" stroke="#fae0aa" stroke-width="2" stroke-linecap="round"/>
<path d="M137 125 L136 166" stroke="#6f4521" stroke-width="2.2"/>
<circle cx="141" cy="124" r="11" fill="url(#gold)" stroke="#65401f" stroke-width="2"/>
<circle cx="141" cy="124" r="4.5" fill="url(#rivet)"/>
<g stroke="#60401f" stroke-width="2.2"><circle cx="88" cy="191" r="21" fill="url(#gold)"/><circle cx="171" cy="191" r="21" fill="url(#gold)"/></g>
<g fill="#63401e" stroke="#ffe09c" stroke-width="1.5"><circle cx="88" cy="191" r="12"/><circle cx="171" cy="191" r="12"/></g>
<path d="M72 182 A20 20 0 0 1 102 177 M154 180 A20 20 0 0 1 186 180" fill="none" stroke="#fff0ac" stroke-width="2.2"/>
<g fill="url(#stone)" stroke="#465262" stroke-width="2"><circle cx="82" cy="82" r="23"/><circle cx="128" cy="67" r="27"/><circle cx="174" cy="82" r="23"/></g>
<path d="M65 76 Q70 62 85 62 M109 59 Q117 44 132 43 M158 75 Q163 62 177 62" fill="none" stroke="#fff9e8" stroke-opacity=".65" stroke-width="2.2" stroke-linecap="round"/>
<path d="M67 80 L73 73 L81 73 M116 74 L120 70 L125 73 M176 91 L181 86 L189 86" fill="none" stroke="#606b73" stroke-opacity=".3" stroke-width="1.4"/>'''


def write_svg(name, body):
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="288" viewBox="0 0 256 288">\n' + body + '\n</svg>\n'
    (MASTER / name).write_text(svg, encoding="utf-8")
    (RUNTIME / name).write_text(svg, encoding="utf-8")


for team in ("blue", "red"):
    for name, symbol in (("infantry", infantry), ("crossbow", crossbow), ("cavalry", cavalry), ("siege", siege)):
        write_svg(f"combat_group_{name}_{team}.svg", definitions(team) + crest_base() + symbol())

write_svg("combat_group_selected_glow.svg", f'''<defs>
<linearGradient id="light" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fff7bd"/><stop offset=".35" stop-color="#ffe457"/><stop offset="1" stop-color="#ffc91e"/></linearGradient>
</defs>
<g fill="none" stroke-linejoin="round">
<path d="{OUTLINE}" stroke="#ffcb19" stroke-opacity=".05" stroke-width="34"/>
<path d="{OUTLINE}" stroke="#ffd72f" stroke-opacity=".09" stroke-width="25"/>
<path d="{OUTLINE}" stroke="#ffdf3c" stroke-opacity=".18" stroke-width="17"/>
<path d="{OUTLINE}" stroke="#ffdb34" stroke-opacity=".36" stroke-width="11"/>
<path d="{OUTLINE}" stroke="url(#light)" stroke-width="7"/>
<path d="{OUTLINE}" stroke="#fff6ac" stroke-opacity=".8" stroke-width="2"/>
</g>''')

write_svg("combat_status_leader.svg", '''<defs>
<linearGradient id="crown" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#fff4b7"/><stop offset=".35" stop-color="#edbe62"/><stop offset=".7" stop-color="#b8782a"/><stop offset="1" stop-color="#f4d487"/></linearGradient>
</defs>
<path d="M39 116 L76 147 L128 69 L180 147 L217 116 L200 210 L56 210 Z" fill="#0d1521" opacity=".5" transform="translate(5 9)"/>
<path d="M39 116 L76 147 L128 69 L180 147 L217 116 L200 210 L56 210 Z" fill="url(#crown)" stroke="#6a451f" stroke-width="5" stroke-linejoin="round"/>
<path d="M43 120 L76 152 L128 77 L180 152 L212 123" fill="none" stroke="#fff3bb" stroke-width="4"/>
<path d="M57 184 L201 184 L197 216 L59 216 Z" fill="url(#crown)" stroke="#6a451f" stroke-width="4"/>
<path d="M60 189 L196 189 M62 211 L194 211" stroke="#fff0ac" stroke-width="3"/>
<g fill="url(#crown)" stroke="#6a451f" stroke-width="3"><circle cx="39" cy="113" r="10"/><circle cx="128" cy="66" r="10"/><circle cx="217" cy="113" r="10"/></g>
<path d="M128 154 L143 173 L128 191 L113 173 Z" fill="#123966" stroke="#fff0a5" stroke-width="4"/>
<path d="M128 159 L137 173 L128 169 L120 173 Z" fill="#70c8e5"/>
<circle cx="77" cy="199" r="4" fill="#7c331f"/><circle cx="179" cy="199" r="4" fill="#7c331f"/>''')

write_svg("combat_status_bolt.svg", '''<defs>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#95a7b8"/><stop offset=".5" stop-color="#f0f3e8"/><stop offset="1" stop-color="#73818c"/></linearGradient>
<linearGradient id="timber" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#a57235"/><stop offset=".5" stop-color="#ffe0a1"/><stop offset="1" stop-color="#a57235"/></linearGradient>
</defs>
<path d="M116 109 L140 109 L140 244 L116 244 Z" fill="url(#timber)" stroke="#684925" stroke-width="3"/>
<path d="M128 30 L155 118 L128 108 L101 118 Z" fill="url(#metal)" stroke="#43515f" stroke-width="3"/>
<path d="M128 32 L128 108 L106 113 Z" fill="#f2f5ee"/>
<path d="M116 200 L99 216 L99 254 L116 242 M140 200 L157 216 L157 254 L140 242" fill="#e4d7ac" stroke="#6f684f" stroke-width="3"/>
<path d="M103 223 L112 215 M144 215 L153 223" stroke="#fff7d8" stroke-width="3"/>''')

print(f"Created 11 SVG combat crests and status icons in {RUNTIME}")

cards = []
for team in ("blue", "red"):
    for role in ("infantry", "crossbow", "cavalry", "siege"):
        selected = '<img class="glow" src="combat_group_selected_glow.svg">' if role == "infantry" else ""
        cards.append(f'<div class="card"><div class="crest"><img src="combat_group_{role}_{team}.svg">{selected}</div><span>{role} / {team}</span></div>')
preview = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Combat shield SVG masters</title>
<style>body{margin:0;background:#262b27;color:#e6d3a2;font:14px Georgia,serif}main{display:grid;grid-template-columns:repeat(4,220px);gap:20px;padding:24px}.card{text-align:center}.crest{position:relative;width:220px;height:247.5px}.crest img{position:absolute;inset:0;width:100%;height:100%}span{display:block;margin-top:5px;letter-spacing:.8px}</style><main>''' + ''.join(cards) + '</main></html>'
(MASTER / "combat_shield_catalog.html").write_text(preview, encoding="utf-8")
