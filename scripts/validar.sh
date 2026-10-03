#!/usr/bin/env bash
# Validacion estatica del repositorio. Corre sin red y sin ejecutar nada del workflow.
# Ver docs/06-reproducibilidad-y-ejecucion.md §9.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# En Windows con Git Bash el ejecutable suele llamarse 'python', no 'python3'.
PY=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1; then
    if "$c" -c "import yaml" >/dev/null 2>&1; then PY="$c"; break; fi
    if [ -z "$PY" ]; then PY="$c"; fi
  fi
done

FALLA=0
nota() { printf '%-58s %s\n' "$1" "$2"; }
fallar() { nota "$1" "FALLO"; FALLA=$((FALLA+1)); }
bien()  { nota "$1" "OK"; }

echo "=== LTSB validacion estatica ==="
echo "raiz: $RAIZ"
echo

# --- 1. YAML de los workflows ---
# GitHub solo lee .github/workflows/. Un workflow en otra carpeta no se ejecuta:
# es el error mas caro y mas silencioso que puede tener este repo.
echo "--- workflows ---"
if [ ! -d .github/workflows ]; then
  fallar "existe el directorio .github/workflows"
fi
for f in .github/workflows/*.yml; do
  [ -e "$f" ] || { echo "(sin workflows)"; break; }
  if [ -n "$PY" ] && "$PY" -c "import yaml,sys;yaml.safe_load(open(sys.argv[1],encoding='utf-8'))" "$f" 2>/dev/null; then
    bien "YAML parseable: $f"
  else
    fallar "YAML parseable: $f"
  fi
done

# Nada de workflows fuera de .github/workflows/: no se ejecutarian.
EXTRA=$(find . -path ./.git -prune -o -name '*.yml' -print 2>/dev/null | grep -v '^\./\.github/workflows/' | grep -v '^\./\.planning/')
if [ -n "$EXTRA" ]; then
  fallar "workflows fuera de .github/workflows (no se ejecutarian):"
  echo "$EXTRA" | sed 's/^/     /'
fi

# --- 2. Shell de los bloques run: ---
# Solo los pasos cuyo shell es de Unix pasan por 'bash -n'. Un paso con
# 'shell: powershell' es codigo de PowerShell: pasarlo por bash daria un falso
# fallo y, peor, daria la sensacion de que algo se reviso cuando no se reviso.
# Esos pasos se delegan a validar-powershell.ps1, que ademas mira los .ps1 del
# repo (que es donde vive la logica real de EXP-000).
echo
echo "--- bash de los pasos run: (solo shell unix) ---"
if [ -n "$PY" ]; then
  # Directorio temporal DENTRO del repo: en Windows, mktemp devuelve una ruta con
  # separadores nativos y 'bash -n' no la resuelve.
  TMP=".tmp-validar"
  rm -rf "$TMP"; mkdir -p "$TMP"
  "$PY" - "$TMP" <<'PY' > "$TMP/lista.txt"
import sys, glob, os
try:
    import yaml
except ImportError:
    sys.exit(0)
tmp = sys.argv[1]
n = 0
for wf in sorted(glob.glob('.github/workflows/*.yml')):
    d = yaml.safe_load(open(wf, encoding='utf-8'))
    for job, jd in (d.get('jobs') or {}).items():
        for i, step in enumerate(jd.get('steps') or []):
            run = step.get('run')
            if not run:
                continue
            shell = str(step.get('shell') or 'bash')
            if 'pwsh' in shell or 'powershell' in shell:
                print('PWSH\t%s\t%s\t%s' % (wf, job, step.get('name', i)))
                continue
            n += 1
            # Separador '/' explicito: os.path.join en Windows produce backslashes
            # y 'bash -n' no las resuelve.
            p = tmp + '/s%d.sh' % n
            open(p, 'w', encoding='utf-8').write(run)
            print("BASH\t%s\t%s\t%s\t%s" % (wf, job, step.get('name', i), p))
PY
  N_BASH=0
  N_PWSH=0
  while IFS=$'\t' read -r tipo wf job name path; do
    # En Windows, print() de Python escribe CRLF: hay que quitar el CR del final o
    # bash intentara abrir 's1.sh\r'.
    path="${path%$'\r'}"
    name="${name%$'\r'}"
    if [ "$tipo" = "PWSH" ]; then
      N_PWSH=$((N_PWSH+1))
      continue
    fi
    N_BASH=$((N_BASH+1))
    if bash -n "$path" 2>"$TMP/err"; then
      bien "bash -n: $name"
    else
      fallar "bash -n: $name"
      sed 's/^/     /' "$TMP/err"
    fi
  done < "$TMP/lista.txt"
  echo "  pasos bash revisados: $N_BASH"
  echo "  pasos powershell (los revisa validar-powershell.ps1): $N_PWSH"
  rm -rf "$TMP"
else
  echo "(python3 no disponible, se omite)"
fi

# --- 3. actionlint si esta ---
echo
echo "--- actionlint ---"
if command -v actionlint >/dev/null 2>&1; then
  if actionlint; then bien "actionlint"; else fallar "actionlint"; fi
else
  echo "(actionlint no instalado, se omite)"
fi

# --- 4. shellcheck si esta ---
echo
echo "--- shellcheck ---"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -x scripts/*.sh 2>/dev/null; then bien "shellcheck"; else fallar "shellcheck"; fi
else
  echo "(shellcheck no instalado, se omite)"
fi

# --- 5. Bloques powershell: no parseables aqui, se delegan ---
echo
echo "--- powershell ---"
if command -v powershell.exe >/dev/null 2>&1; then
  # indentado 2 para que el ok/error quede alineado con el resto de la salida
  if powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validar-powershell.ps1 >/dev/null 2>&1; then
    bien "bloques powershell (detalle en la salida de validar-powershell.ps1)"
  else
    fallar "bloques powershell: ver detalle ejecutando scripts/validar-powershell.ps1"
  fi
else
  echo "(powershell.exe no disponible desde este shell, se omite)"
  echo "  en Windows: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\validar-powershell.ps1"
fi

# --- 6. Enlaces markdown relativos ---
echo
echo "--- enlaces markdown ---"
if [ -n "$PY" ]; then
  "$PY" - <<'PY'
import glob, os, re, sys
bad = 0
for p in glob.glob('**/*.md', recursive=True):
    if p.startswith('.planning/'):
        continue
    base = os.path.dirname(p)
    txt = open(p, encoding='utf-8').read()
    # solo enlaces de ruta, no referencias de tipo Markdown: [texto](file#ancla) se filtra
    for m in re.finditer(r'\]\(([^)#:\s]+)\)', txt):
        t = m.group(1)
        if t.startswith(('http://', 'https://', 'mailto:')):
            continue
        f = os.path.normpath(os.path.join(base, t))
        if not os.path.exists(f):
            print('    ROTO %s -> %s' % (p, t))
            bad += 1
print('    enlaces rotos:', bad)
sys.exit(1 if bad else 0)
PY
  if [ $? -eq 0 ]; then bien "enlaces relativos"; else fallar "enlaces relativos"; fi
fi

# --- 7. Caracteres corruptos ---
# Han entrado caracteres CJK y U+FFFD en varios archivos de este repo durante
# la redaccion. Son invisibles en el diff y en el editor, asi que hace falta
# buscarlos explicitamente. El proyecto es en espanol: cualquier ideograma en un
# texto del repo es un error, salvo que este citado a proposito.
echo
echo "--- caracteres corruptos ---"
if [ -n "$PY" ]; then
  "$PY" - <<'PY'
import os, re, sys
bad = 0
EXT = {'.md', '.sh', '.ps1', '.yml', '.yaml', '.txt', '.json', '.gitignore'}
RAIZ = '.'
# Rangos CJK, hiragana, katakana, hangul y puntuacion CJK.
CJK = re.compile(
    '[\u3000-\u303f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff'
    '\uf900-\ufaff\uff00-\uffef\uac00-\ud7af]')
FFFD = '\ufffd'

for dirpath, dirnames, filenames in os.walk(RAIZ):
    dirnames[:] = [d for d in dirnames
                   if d not in ('.git', 'node_modules', '.planning', '.tmp-validar')
                   and not d.startswith('.tmp-')]
    for fn in filenames:
        ext = os.path.splitext(fn)[1].lower()
        if ext not in EXT and fn != '.gitignore':
            continue
        p = os.path.join(dirpath, fn)
        try:
            txt = open(p, encoding='utf-8').read()
        except (UnicodeDecodeError, OSError):
            print('    ILEGIBLE %s (no es UTF-8 valido)' % p)
            bad += 1
            continue
        for i, linea in enumerate(txt.splitlines(), 1):
            m = CJK.search(linea)
            if m:
                print('    CJK %s:%d -> %r' % (p, i, m.group(0)))
                bad += 1
            if FFFD in linea:
                print('    U+FFFD %s:%d' % (p, i))
                bad += 1
print('    hallazgos:', bad)
sys.exit(1 if bad else 0)
PY
  if [ $? -eq 0 ]; then bien "sin CJK ni U+FFFD"; else fallar "caracteres corruptos"; fi
fi

echo
echo "--- unattend: namespace wcm y well-formedness ---"
WF=".github/workflows/10-sonda-disco-construccion.yml"
# Sin xmlns:wcm el unattend usa prefijos no declarados: no es well-formed,
# Setup lo ignora y arranca la UI interactiva. Se comprueba de forma estatica.
if grep -q 'wcm:action=' "$WF"; then
  if grep -q 'xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"' "$WF"; then
    bien "unattend declara xmlns:wcm"
  else
    fallar "el unattend usa wcm:action pero NO declara xmlns:wcm (Setup lo ignoraria)"
  fi
fi
if grep -q 'xmllint --noout aio/autoinstall.xml' "$WF"; then
  bien "el workflow valida la well-formedness del unattend en tiempo de ejecucion"
else
  fallar "el workflow no valida la well-formedness del unattend"
fi

echo
echo "--- unattend: estructura del esquema Microsoft-Windows-Setup ---"
# xmllint solo dice si el XML esta bien FORMADO. Un unattend bien formado puede
# ser invalido contra el esquema, y Setup responde:
#   "a component or setting specified in autounattend.xml for pass [windowsPE]
#    is missing or invalid"
# El caso real: ImageInstall y UserData anidados DENTRO de DiskConfiguration.
# En el esquema son HERMANOS de DiskConfiguration, y los unicos hijos validos de
# DiskConfiguration son Disk y WillShowUI. Por eso se comprueba la estructura.
python3 - "$WF" <<'PY'
import re, sys, xml.etree.ElementTree as ET

NS = "{urn:schemas-microsoft-com:unattend}"
WF = sys.argv[1]
txt = open(WF, encoding="utf-8").read()
m = re.search(r"cat > \S+\.xml <<'XML'\n(.*?)\n\s*XML\n", txt, re.S)
if not m:
    print("  AVISO: no se encontro el heredoc XML en", WF)
    sys.exit(0)

# Reproducir la des-indentacion que hace bash con <<'XML' (quita 10 espacios).
doc = "\n".join(l[10:] if l.startswith(" " * 10) else l
                for l in m.group(1).split("\n"))
try:
    root = ET.fromstring(doc)
except ET.ParseError as e:
    print("  [FALLO] el unattend no es well-formed:", e)
    sys.exit(1)

bad = 0
found_setup = False

# El esquema XSD de unattend define SECUENCIAS: el orden de los elementos dentro
# de un padre es obligatorio. Setup responde "The answer file is invalid for pass
# [windowsPE]" cuando el orden no coincide, y el XML sigue siendo well-formed.
SECUENCIAS = {
    "CreatePartition": ["Order", "Size", "Type", "Extend"],
    "ModifyPartition": ["Order", "PartitionID", "Active", "Format", "Label"],
    "OSImage":         ["InstallFrom", "InstallTo", "WillShowUI", "Compact"],
}


def comprobar_secuencia(elem, ruta):
    global bad
    esperado = SECUENCIAS[elem.tag.replace(NS, "")]
    hijos = [k.tag.replace(NS, "") for k in elem]
    # indice de la ultima posicion conocida, para detectar saltos hacia atras
    ultimo = -1
    for h in hijos:
        if h not in esperado:
            print("  [FALLO] %s: <%s> no pertenece a %s" % (ruta, h, elem.tag.replace(NS, "")))
            bad += 1
            continue
        pos = esperado.index(h)
        if pos < ultimo:
            print("  [FALLO] %s: orden invalido en %s -> %s"
                  % (ruta, elem.tag.replace(NS, ""), " ".join(hijos)))
            print("          el esquema exige: " + " ".join(esperado))
            bad += 1
            break
        ultimo = pos


def recorrer(elem, ruta):
    tag = elem.tag.replace(NS, "")
    if tag in SECUENCIAS:
        comprobar_secuencia(elem, ruta)
    for k in elem:
        recorrer(k, ruta + "/" + tag)


for st in root.findall(NS + "settings"):
    for comp in st.findall(NS + "component"):
        if comp.get("name") != "Microsoft-Windows-Setup":
            continue
        found_setup = True
        dc = comp.find(NS + "DiskConfiguration")
        if dc is None:
            print("  [FALLO] Microsoft-Windows-Setup sin DiskConfiguration")
            bad += 1
        else:
            hijos = [k.tag.replace(NS, "") for k in dc]
            ilegales = [h for h in hijos if h not in ("Disk", "WillShowUI")]
            if ilegales:
                print("  [FALLO] hijos invalidos de DiskConfiguration:", "|".join(ilegales))
                print("          deben ser HERMANOS de DiskConfiguration, no hijos")
                bad += 1
        for req in ("ImageInstall", "UserData"):
            if comp.find(NS + req) is None:
                print("  [FALLO] falta <%s> como hermano de DiskConfiguration" % req)
                bad += 1
        recorrer(comp, st.get("pass", "?"))

if not found_setup:
    print("  AVISO: no se encontro el componente Microsoft-Windows-Setup")
if bad == 0:
    print("  OK  estructura y orden de Microsoft-Windows-Setup validos")
sys.exit(1 if bad else 0)
PY
if [ $? -eq 0 ]; then
  bien "estructura del unattend valida contra el esquema"
else
  fallar "el unattend es invalido contra el esquema; Setup abortaria en windowsPE"
fi

echo
if [ "$FALLA" -eq 0 ]; then
  echo "=== resultado: sin fallos ==="
else
  echo "=== resultado: $FALLA fallo(s) ==="
fi
exit "$FALLA"
