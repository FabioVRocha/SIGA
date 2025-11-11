# Importa as classes e funções necessárias do Flask
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify, send_file, abort
# Importa o módulo para conectar ao PostgreSQL
import psycopg2
# Importa o módulo para lidar com erros de banco de dados
from psycopg2 import Error
from psycopg2.errors import UndefinedColumn
import datetime # Para formatar datas
import calendar  # Para cálculo de dias úteis
from functools import wraps # Para criar um decorador de login
# Importa as funções para hashing de senhas
from werkzeug.security import generate_password_hash, check_password_hash
import re # Para expressões regulares, usado para parsear rgcdes
import json # Para lidar com dados JSON (para parâmetros de usuário)
import math
from math import isclose
from decimal import Decimal, InvalidOperation
import urllib.parse
import urllib.request
import urllib.error
import itertools
import base64
import mimetypes
import ssl
from pathlib import Path
import threading

# Importa as configurações do arquivo config.py
from config import DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT, SECRET_KEY, SYSTEM_VERSION, LOGGED_IN_USER, SIGA_DB_NAME, USER_PARAMETERS_TABLE

# Inicializa a aplicação Flask
app = Flask(__name__)
# Define a chave secreta importada do config.py
app.secret_key = SECRET_KEY

AVAILABLE_PARAMETER_REPORTS = [
    ('report_revenue_comparison', 'Comparativo de Faturamento'),
    ('report_revenue_by_cfop', 'Faturamento por CFOP'),
    ('report_revenue_by_line', 'Faturamento por Linha'),
    ('report_average_price', 'Preço Médio'),
    ('report_revenue_by_day', 'Faturamento por Dia'),
    ('report_revenue_by_state', 'Faturamento por Estado'),
    ('report_revenue_by_vendor', 'Faturamento por Vendedor'),
    ('invoices_mirror', 'Espelho de Notas Fiscais Faturadas'),
]

REPORT_SALES_COMPARISON_FILTERS_PARAM = 'report_sales_orders_comparison_filters'
REPORT_ORDERS_BY_STATE_FILTERS_PARAM = 'report_orders_by_state_filters'
REPORT_ORDERS_LINE_FILTERS_PARAM = 'report_orders_by_line_filters'
REPORT_DECOMPOSITION_TREE_FILTERS_PARAM = 'report_decomposition_tree_filters'

ORDER_APPROVAL_STATUS_OPTIONS = [
    {'code': 'S', 'label': 'Aprovado'},
    {'code': 'N', 'label': 'Não Aprovado'},
    {'code': 'C', 'label': 'Cancelado'},
]

ORDER_APPROVAL_STATUS_LABELS = {
    option['code']: option['label'] for option in ORDER_APPROVAL_STATUS_OPTIONS
}

ORDER_SITUATION_OPTIONS = [
    {'code': 'A', 'label': 'Atendido'},
    {'code': '', 'label': 'Em Aberto'},
    {'code': 'C', 'label': 'Cancelado'},
    {'code': 'P', 'label': 'Parcial'},
]

ORDER_SITUATION_LABELS = {
    option['code']: option['label'] for option in ORDER_SITUATION_OPTIONS
}

REPORT_ORDERS_REP_FILTERS_PARAM = 'report_orders_by_representatives_filters'

TECHNICAL_ASSISTANCE_STATUS_LABELS = {
    'A': 'Aberta',
    'AB': 'Aberta',
    'AT': 'Atendida',
    'F': 'Finalizada',
    'FI': 'Finalizada',
    'C': 'Cancelada',
    'CA': 'Cancelada',
    'P': 'Pendente',
    'PE': 'Pendente',
    'PT': 'Pendente',
    'E': 'Em andamento',
    'EM': 'Em andamento',
    'S': 'Suspensa',
}

TECHNICAL_ASSISTANCE_SITUATION_LABELS = {
    'A': 'Aberta',
    'AT': 'Atendida',
    'AP': 'Aprovada',
    'F': 'Finalizada',
    'C': 'Cancelada',
    'CA': 'Cancelada',
    'P': 'Pendente',
    'E': 'Em andamento',
    'S': 'Suspensa',
    'NA': 'Não Aprovada',
}

ASSISTANCE_STATUS_OPTIONS = [
    {'code': 'AT', 'label': TECHNICAL_ASSISTANCE_STATUS_LABELS.get('AT', 'Atendida')},
    {'code': 'PT', 'label': TECHNICAL_ASSISTANCE_STATUS_LABELS.get('PT', 'Pendente')},
]

ASSISTANCE_SITUATION_OPTIONS = [
    {'code': 'AP', 'label': TECHNICAL_ASSISTANCE_SITUATION_LABELS.get('AP', 'Aprovada')},
    {'code': 'CA', 'label': TECHNICAL_ASSISTANCE_SITUATION_LABELS.get('CA', 'Cancelada')},
    {'code': 'NA', 'label': TECHNICAL_ASSISTANCE_SITUATION_LABELS.get('NA', 'Não Aprovada')},
]

def _format_combined_filter_label(code, order_labels, assistance_labels):
    """Compose a friendly label for filters that mix pedidos and assistências."""
    order_label = (order_labels.get(code) or '').strip()
    assistance_label = (assistance_labels.get(code) or '').strip()
    if order_label and assistance_label:
        if order_label.lower() == assistance_label.lower():
            base = order_label or assistance_label
            combined = f"{base} (Pedido e Assistência)"
        else:
            combined = f"{order_label} (Pedido) / {assistance_label} (Assistência)"
    elif order_label:
        combined = f"{order_label} (Pedido)"
    elif assistance_label:
        combined = f"{assistance_label} (Assistência)"
    else:
        combined = 'Não Informado'

    code_text = str(code or '').strip()
    if code_text:
        return f"{code_text} - {combined}"
    return combined


def _build_combined_filter_options(order_labels, assistance_labels):
    """Builds ordered filter options joining pedido and assistência codes."""
    options = []
    seen = set()
    for labels in (order_labels, assistance_labels):
        for code in labels.keys():
            if code in seen:
                continue
            seen.add(code)
            options.append(
                {
                    'code': code,
                    'label': _format_combined_filter_label(code, order_labels, assistance_labels),
                }
            )
    return options


MAP_APPROVAL_STATUS_OPTIONS = _build_combined_filter_options(
    ORDER_APPROVAL_STATUS_LABELS, TECHNICAL_ASSISTANCE_STATUS_LABELS
)
MAP_APPROVAL_STATUS_CODES = {option['code'] for option in MAP_APPROVAL_STATUS_OPTIONS}

MAP_SITUATION_OPTIONS = _build_combined_filter_options(
    ORDER_SITUATION_LABELS, TECHNICAL_ASSISTANCE_SITUATION_LABELS
)
MAP_SITUATION_CODES = {option['code'] for option in MAP_SITUATION_OPTIONS}

SEPARATION_STAGE_OPTIONS = [
    {'code': 'zero', 'label': 'Igual a zero'},
    {'code': 'partial', 'label': 'Parcial'},
    {'code': 'total', 'label': 'Total'},
]

VALID_SEPARATION_STAGE_CODES = {option['code'] for option in SEPARATION_STAGE_OPTIONS}
SEPARATION_STAGE_LABELS = {option['code']: option['label'] for option in SEPARATION_STAGE_OPTIONS}
SEPARATION_STAGE_LABELS.setdefault('carregado', 'Carregado')

OCCURRENCE_BLANK_VALUE = '__blank__'

LOAD_LOT_ROUTE_PARAM_NAME = 'load_lot_route_prefs'
LOAD_ROUTE_FILTERS_PARAM_NAME = 'load_route_planner_filters'
LOAD_ROUTE_FILTERS_PARAM_NAME_V2 = 'load_route_planner_v2_filters'

MAP_DOCUMENT_SOURCE_OPTIONS = [
    {'value': 'both', 'label': 'Pedidos e Assistências'},
    {'value': 'orders', 'label': 'Somente Pedidos'},
    {'value': 'assistances', 'label': 'Somente Assistências'},
]

MAP_DOCUMENT_SOURCE_RECORD_TYPES = {
    'both': ['consulta_pedidos', 'pedidos_vendas', 'assistencia_tecnica'],
    'orders': ['consulta_pedidos', 'pedidos_vendas'],
    'assistances': ['assistencia_tecnica'],
}

RECORD_TYPE_LABELS = {
    'consulta_pedidos': 'Pedido',
    'pedidos_vendas': 'Pedido',
    'assistencia_tecnica': 'Assistência',
}

ASSISTANCE_MEDIA_PATH_PARAM = 'technical_assistance_media_base_path'
ASSISTANCE_MEDIA_IMAGE_EXTENSIONS = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.tif',
    '.tiff',
    '.heic',
}
ASSISTANCE_MEDIA_VIDEO_EXTENSIONS = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.wmv',
    '.webm',
    '.m4v',
}
ASSISTANCE_MEDIA_PDF_EXTENSIONS = {
    '.pdf',
}
OSRM_TABLE_BASE_URL = 'https://router.project-osrm.org/table/v1/driving/'
NOMINATIM_USER_AGENT = 'SIGA/1.0 (contato@siga.app)'
AVERAGE_SPEED_KMH = 60
GEOCODE_CACHE = {}
GEOCODE_CACHE_FILE = Path(__file__).resolve().parent / 'Temp' / 'geocode_cache.json'
GEOCODE_CACHE_LOCK = threading.Lock()
TABLE_COLUMNS_CACHE = {}
TABLE_COLUMN_EXISTS_CACHE = {}
TABLE_METADATA_LOCK = threading.Lock()


def _ensure_directory(path_obj):
    """Garante que o diretório pai do caminho informado exista."""
    try:
        path_obj.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        pass


def load_geocode_cache_from_disk():
    """Inicializa o cache de geocodificação a partir do disco, se disponível."""
    if not GEOCODE_CACHE_FILE.exists():
        return
    try:
        with GEOCODE_CACHE_FILE.open('r', encoding='utf-8') as handle:
            raw_payload = json.load(handle)
    except (OSError, ValueError, json.JSONDecodeError):
        return
    if not isinstance(raw_payload, list):
        return
    with GEOCODE_CACHE_LOCK:
        for entry in raw_payload:
            if not isinstance(entry, dict):
                continue
            city = (entry.get('city') or '').strip().lower()
            state = (entry.get('state') or '').strip().lower()
            lat = entry.get('lat')
            lon = entry.get('lon')
            try:
                lat_val = float(lat)
                lon_val = float(lon)
            except (TypeError, ValueError):
                continue
            if not city and not state:
                continue
            GEOCODE_CACHE[(city, state)] = (lat_val, lon_val)


def _persist_geocode_cache():
    """Salva o cache de geocodificação em disco."""
    with GEOCODE_CACHE_LOCK:
        if not GEOCODE_CACHE:
            data = []
        else:
            data = [
                {
                    'city': city,
                    'state': state,
                    'lat': coords[0],
                    'lon': coords[1],
                }
                for (city, state), coords in GEOCODE_CACHE.items()
            ]
    try:
        _ensure_directory(GEOCODE_CACHE_FILE)
        with GEOCODE_CACHE_FILE.open('w', encoding='utf-8') as handle:
            json.dump(data, handle)
    except OSError:
        pass


def table_has_column(conn, table_name, column_name):
    """Verifica a existência de uma coluna na tabela, reutilizando um cache em memória."""
    normalized_table = (table_name or '').strip().lower()
    normalized_column = (column_name or '').strip().lower()
    if not normalized_table or not normalized_column:
        return False
    cache_key = (normalized_table, normalized_column)
    with TABLE_METADATA_LOCK:
        cached_value = TABLE_COLUMN_EXISTS_CACHE.get(cache_key)
    if cached_value is not None:
        return cached_value

    owns_connection = False
    if conn is None:
        conn = get_erp_db_connection()
        owns_connection = True

    exists = False
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_name = %s
                      AND column_name = %s
                )
                """,
                (normalized_table, normalized_column),
            )
            result = cur.fetchone()
            if result:
                exists = bool(result[0])
            cur.close()
        except Error as error:
            print(f"Erro ao verificar coluna '{normalized_column}' na tabela '{normalized_table}': {error}")
    if owns_connection and conn:
        conn.close()
    with TABLE_METADATA_LOCK:
        TABLE_COLUMN_EXISTS_CACHE[cache_key] = exists
    return exists


def get_table_columns(conn, table_name):
    """Retorna o conjunto de colunas disponíveis para a tabela informada."""
    normalized_table = (table_name or '').strip().lower()
    if not normalized_table:
        return set()
    with TABLE_METADATA_LOCK:
        cached_columns = TABLE_COLUMNS_CACHE.get(normalized_table)
    if cached_columns is not None:
        return cached_columns

    owns_connection = False
    if conn is None:
        conn = get_erp_db_connection()
        owns_connection = True

    columns = set()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = %s
                """,
                (normalized_table,),
            )
            columns = {
                (row[0] or '').lower()
                for row in cur.fetchall()
                if row and row[0]
            }
            cur.close()
        except Error as error:
            print(f"Erro ao buscar colunas da tabela '{normalized_table}': {error}")
    if owns_connection and conn:
        conn.close()
    with TABLE_METADATA_LOCK:
        TABLE_COLUMNS_CACHE[normalized_table] = columns
    return columns


load_geocode_cache_from_disk()
MAX_BRUTE_FORCE_ORDERS = 8
INSECURE_SSL_CONTEXT = ssl._create_unverified_context()

BRAZIL_STATE_CODES = (
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
    'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
)


def route_sequence_sort_value(raw_value):
    """Normaliza o valor de sequência para permitir ordenação consistente."""
    if raw_value is None:
        return (float('inf'), '')
    seq_str = str(raw_value).strip()
    if not seq_str:
        return (float('inf'), '')
    digits_only = ''.join(ch for ch in seq_str if ch.isdigit())
    if digits_only:
        try:
            return (int(digits_only), seq_str)
        except ValueError:
            pass
    try:
        normalized = seq_str.replace(',', '.')
        return (float(normalized), seq_str)
    except ValueError:
        return (float('inf'), seq_str)


def load_route_preferences_for_user(user_id):
    """Recupera as preferências de pontos inicial/final salvas para o usuário."""
    route_preferences = {
        'start': {'enabled': False, 'cidade': '', 'estado': ''},
        'end': {'enabled': False, 'cidade': '', 'estado': ''},
    }
    if not user_id:
        return route_preferences
    stored_prefs = get_user_parameters(user_id, LOAD_LOT_ROUTE_PARAM_NAME)
    if not stored_prefs:
        return route_preferences
    try:
        parsed = json.loads(stored_prefs)
        for key in ('start', 'end'):
            if key in parsed and isinstance(parsed[key], dict):
                route_preferences[key]['enabled'] = bool(parsed[key].get('enabled'))
                route_preferences[key]['cidade'] = (parsed[key].get('cidade') or '').strip()
                route_preferences[key]['estado'] = (parsed[key].get('estado') or '').strip()
    except (json.JSONDecodeError, TypeError):
        pass
    return route_preferences


def build_route_payload_from_orders(orders, preferred_sequence_field=None):
    """Monta a estrutura utilizada no mapa a partir da lista de pedidos."""
    payload = []
    for index, order in enumerate(orders):
        if preferred_sequence_field:
            preferred_value = order.get(preferred_sequence_field)
            sequence_display = str(preferred_value) if preferred_value else str(index + 1)
        else:
            sequence_display = order.get('sequencia') or str(index + 1)
        payload.append(
            {
                'pedido': order.get('pedido', ''),
                'sequencia': order.get('sequencia', ''),
                'cliente': order.get('cliente', ''),
                'cidade': order.get('cidade', ''),
                'estado': order.get('estado', ''),
                'latitude': order.get('latitude'),
                'longitude': order.get('longitude'),
                'sequence_display': sequence_display,
                'marker_type': 'order',
                'order_index': index,
            }
        )
    return payload


def build_custom_point(route_preferences, pref_key, label, marker_type):
    """Cria um ponto artificial para o mapa a partir das preferências salvas."""
    config = route_preferences.get(pref_key, {})
    enabled = config.get('enabled')
    city = (config.get('cidade') or '').strip()
    state = (config.get('estado') or '').strip()
    if not enabled or not (city or state):
        return None
    return {
        'pedido': '',
        'sequencia': '',
        'sequence_display': label,
        'cliente': 'Ponto ' + ('Inicial' if pref_key == 'start' else 'Final'),
        'cidade': city,
        'estado': state,
        'latitude': None,
        'longitude': None,
        'marker_type': marker_type,
        'order_index': None,
    }


def build_map_waypoints(route_payload, route_preferences):
    """Combina cargas reais com pontos customizados para renderizar no mapa."""
    map_waypoints = []
    custom_start = build_custom_point(route_preferences, 'start', 'I', 'custom-start')
    custom_end = build_custom_point(route_preferences, 'end', 'F', 'custom-end')
    if custom_start:
        map_waypoints.append(custom_start)
    map_waypoints.extend(route_payload)
    if custom_end:
        map_waypoints.append(custom_end)
    return map_waypoints


def has_valid_coordinates(order):
    """Determina se o pedido possui coordenadas geográficas utilizáveis."""
    lat = order.get('latitude')
    lon = order.get('longitude')
    if lat in (None, '') or lon in (None, ''):
        return False
    try:
        lat = float(lat)
        lon = float(lon)
    except (TypeError, ValueError):
        return False
    if math.isclose(lat, 0.0, abs_tol=1e-9) and math.isclose(lon, 0.0, abs_tol=1e-9):
        return False
    return True


def haversine_distance_km(point_a, point_b):
    """Calcula a distância aproximada entre dois pontos geográficos."""
    lat1, lon1 = point_a
    lat2, lon2 = point_b
    radius = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    a = math.sin(d_lat / 2) ** 2 + math.sin(d_lon / 2) ** 2 * math.cos(lat1_rad) * math.cos(lat2_rad)
    c = 2 * math.asin(min(1, math.sqrt(a)))
    return radius * c


def normalize_coordinate_value(value):
    """Normaliza coordenadas em ponto flutuante."""
    if value in (None, ''):
        return None
    if isinstance(value, Decimal):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


EMP_OBSERVATION_LAT_PATTERN = re.compile(
    r'\bLAT(?:ITUDE)?\s*[:=]?\s*(-?\d+(?:[.,]\d+)?)',
    re.IGNORECASE,
)
EMP_OBSERVATION_LON_PATTERN = re.compile(
    r'\bLO(?:NG(?:ITUDE)?|N)\s*[:=]?\s*(-?\d+(?:[.,]\d+)?)',
    re.IGNORECASE,
)


def _safe_parse_float(value):
    """Converte texto em float usando Decimal para maior tolerância."""
    if value in (None, ''):
        return None
    try:
        return float(Decimal(str(value).strip()))
    except (InvalidOperation, ValueError, TypeError):
        return None


def parse_coordinates_from_observation(observation_text):
    """
    Extrai latitude e longitude de um texto de observação da empresa.
    Espera padrões como 'LAT: -3.16' e 'LON: -40.08'.
    """
    if not observation_text:
        return None, None

    normalized = observation_text.replace(',', '.')
    lat_match = EMP_OBSERVATION_LAT_PATTERN.search(normalized)
    lon_match = EMP_OBSERVATION_LON_PATTERN.search(normalized)

    latitude_value = _safe_parse_float(lat_match.group(1)) if lat_match else None
    longitude_value = _safe_parse_float(lon_match.group(1)) if lon_match else None

    return latitude_value, longitude_value


def fetch_customer_coordinates_from_observations(company_codes):
    """
    Busca coordenadas a partir das observações cadastradas na tabela empresa1.
    Retorna um dicionário {empresa: {'latitude': lat, 'longitude': lon}}.
    """
    normalized_codes = []
    seen = set()
    for code in company_codes or []:
        text = str(code or '').strip()
        if not text or text in seen:
            continue
        seen.add(text)
        normalized_codes.append(text)

    if not normalized_codes:
        return {}

    coords_map = {}
    conn = get_erp_db_connection()
    if not conn:
        return coords_map

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT
                CAST(e1.empresa AS TEXT) AS empresa,
                COALESCE(e1.empseqobs, 0) AS sequencia,
                COALESCE(e1.empobserva, '') AS observacao
            FROM empresa1 e1
            WHERE CAST(e1.empresa AS TEXT) = ANY(%s)
            ORDER BY CAST(e1.empresa AS TEXT), COALESCE(e1.empseqobs, 0)
            """,
            (normalized_codes,),
        )
        aggregated = {}
        for empresa_raw, _, observacao_raw in cur.fetchall():
            key = (empresa_raw or '').strip()
            if not key:
                continue
            aggregated.setdefault(key, []).append(observacao_raw or '')

        for empresa, fragments in aggregated.items():
            combined_text = ' '.join(
                fragment.strip() for fragment in fragments if fragment and fragment.strip()
            )
            latitude_value, longitude_value = parse_coordinates_from_observation(combined_text)
            if latitude_value is None or longitude_value is None:
                continue
            coords_map[empresa] = {
                'latitude': latitude_value,
                'longitude': longitude_value,
            }
    except (Exception, Error) as exc:
        print(f"Erro ao carregar coordenadas de empresa1: {exc}")
    finally:
        if cur:
            cur.close()
        conn.close()

    return coords_map


def geocode_city_state(city, state, cache=None):
    """Obtém coordenadas para uma cidade/UF utilizando Nominatim."""
    normalized_city = (city or '').strip()
    normalized_state = (state or '').strip()
    if not normalized_city and not normalized_state:
        return None
    use_global_cache = cache is None or cache is GEOCODE_CACHE
    cache_ref = GEOCODE_CACHE if use_global_cache else cache
    cache_key = (normalized_city.lower(), normalized_state.lower())
    if use_global_cache:
        with GEOCODE_CACHE_LOCK:
            cached_value = cache_ref.get(cache_key)
    else:
        cached_value = cache_ref.get(cache_key)
    if cached_value:
        return cached_value
    params = {
        'format': 'json',
        'limit': 1,
        'countrycodes': 'br',
        'q': ', '.join([part for part in (normalized_city, normalized_state, 'Brasil') if part]),
        'email': 'contato@siga.app',
    }
    url = f"https://nominatim.openstreetmap.org/search?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={'User-Agent': NOMINATIM_USER_AGENT})
    try:
        try:
            response = urllib.request.urlopen(request, timeout=8)
        except urllib.error.URLError as error:
            if isinstance(getattr(error, 'reason', None), ssl.SSLCertVerificationError):
                response = urllib.request.urlopen(request, timeout=8, context=INSECURE_SSL_CONTEXT)
            else:
                return None
        except ssl.SSLCertVerificationError:
            response = urllib.request.urlopen(request, timeout=8, context=INSECURE_SSL_CONTEXT)
        with response:
            payload = response.read().decode('utf-8')
            results = json.loads(payload)
    except (urllib.error.URLError, ValueError, TimeoutError):
        return None
    if not results:
        return None
    try:
        lat = float(results[0]['lat'])
        lon = float(results[0]['lon'])
    except (KeyError, ValueError, TypeError):
        return None
    coords = (lat, lon)
    if use_global_cache:
        with GEOCODE_CACHE_LOCK:
            cache_ref[cache_key] = coords
        _persist_geocode_cache()
    else:
        cache_ref[cache_key] = coords
    return coords


def build_haversine_matrices(coords):
    """Cria matrizes de distância e duração utilizando Haversine."""
    total = len(coords)
    distances = [[0.0 for _ in range(total)] for _ in range(total)]
    durations = [[0.0 for _ in range(total)] for _ in range(total)]
    for i in range(total):
        for j in range(i + 1, total):
            dist = haversine_distance_km(coords[i], coords[j])
            distances[i][j] = distances[j][i] = dist
            duration_minutes = (dist / AVERAGE_SPEED_KMH) * 60 if dist else 0.0
            durations[i][j] = durations[j][i] = duration_minutes
    return distances, durations


def fetch_osrm_matrices(coords):
    """Consulta a API OSRM para obter matrizes de distância/tempo."""
    if not coords:
        return None, None
    coord_param = ';'.join(f"{lon:.6f},{lat:.6f}" for lat, lon in coords)
    query = urllib.parse.urlencode({'annotations': 'duration,distance'})
    url = f"{OSRM_TABLE_BASE_URL}{coord_param}?{query}"
    request = urllib.request.Request(url, headers={'User-Agent': NOMINATIM_USER_AGENT})
    try:
        try:
            response = urllib.request.urlopen(request, timeout=12)
        except urllib.error.URLError as error:
            if isinstance(getattr(error, 'reason', None), ssl.SSLCertVerificationError):
                response = urllib.request.urlopen(request, timeout=12, context=INSECURE_SSL_CONTEXT)
            else:
                return None, None
        except ssl.SSLCertVerificationError:
            response = urllib.request.urlopen(request, timeout=12, context=INSECURE_SSL_CONTEXT)
        with response:
            data = json.loads(response.read().decode('utf-8'))
    except (urllib.error.URLError, ValueError, TimeoutError):
        return None, None
    distances_raw = data.get('distances')
    durations_raw = data.get('durations')
    if not distances_raw or not durations_raw:
        return None, None
    distances = []
    durations = []
    for row in distances_raw:
        distances.append([(value / 1000) if value is not None else None for value in row])
    for row in durations_raw:
        durations.append([(value / 60) if value is not None else None for value in row])
    return distances, durations


def build_distance_duration_matrices(coords):
    """Tenta usar OSRM e recorre ao Haversine quando necessário."""
    if len(coords) <= 100:
        distances, durations = fetch_osrm_matrices(coords)
        if distances and durations and all(row.count(None) < len(row) for row in distances):
            return distances, durations, 'osrm'
    distances, durations = build_haversine_matrices(coords)
    return distances, durations, 'haversine'


def matrix_value(matrix, origin_idx, target_idx):
    """Recupera um valor da matriz, retornando infinito quando ausente."""
    if matrix is None or origin_idx is None or target_idx is None:
        return float('inf')
    try:
        value = matrix[origin_idx][target_idx]
    except (IndexError, TypeError):
        return float('inf')
    if value is None:
        return float('inf')
    return float(value)


def optimize_sequence(order_entries, start_idx, end_idx, distance_matrix, anchor_entry=None):
    """Ordena pedidos usando heurística de vizinho mais próximo + 2-opt."""
    if not order_entries and anchor_entry is None:
        return []

    base_entries = list(order_entries)

    def nearest_neighbor_path(initial_entry=None):
        remaining = list(base_entries)
        path = []
        if anchor_entry is not None:
            path.append(anchor_entry)
            current_idx = anchor_entry['matrix_index']
        else:
            current_idx = start_idx

        if anchor_entry is None:
            if initial_entry is not None and remaining:
                chosen_pos = next(
                    (idx for idx, entry in enumerate(remaining) if entry['matrix_index'] == initial_entry['matrix_index']),
                    None
                )
                if chosen_pos is None:
                    chosen_entry = remaining.pop(0)
                else:
                    chosen_entry = remaining.pop(chosen_pos)
                path.append(chosen_entry)
                current_idx = chosen_entry['matrix_index']
            elif current_idx is None and remaining:
                chosen_entry = remaining.pop(0)
                path.append(chosen_entry)
                current_idx = chosen_entry['matrix_index']

        while remaining:
            best_candidate = min(
                remaining,
                key=lambda entry: matrix_value(distance_matrix, current_idx, entry['matrix_index'])
            )
            best_distance = matrix_value(distance_matrix, current_idx, best_candidate['matrix_index'])
            if math.isinf(best_distance):
                next_entry = remaining.pop(0)
            else:
                remaining.remove(best_candidate)
                next_entry = best_candidate
            path.append(next_entry)
            current_idx = next_entry['matrix_index']
        return path

    candidate_paths = []
    if anchor_entry is not None or start_idx is not None:
        candidate_paths.append(nearest_neighbor_path())
    else:
        unique_indices = {entry['matrix_index'] for entry in base_entries}
        index_lookup = {entry['matrix_index']: entry for entry in base_entries}
        for matrix_index in unique_indices:
            candidate_paths.append(nearest_neighbor_path(index_lookup[matrix_index]))

    best_path = None
    best_distance = float('inf')
    for path in candidate_paths:
        if not path:
            continue
        path_start_idx = start_idx if start_idx is not None else path[0]['matrix_index']
        refined = apply_two_opt(path, path_start_idx, end_idx, distance_matrix)
        total_distance = compute_path_distance(refined, distance_matrix, path_start_idx, end_idx)
        if math.isinf(total_distance):
            continue
        if total_distance + 1e-6 < best_distance:
            best_distance = total_distance
            best_path = refined

    if best_path:
        return best_path
    return candidate_paths[0] if candidate_paths else (anchor_entry and [anchor_entry] or [])


def compute_path_distance(sequence, distance_matrix, start_idx, end_idx):
    """Soma as distâncias consecutivas da rota."""
    total = 0.0
    previous_idx = start_idx
    for entry in sequence:
        current_idx = entry['matrix_index']
        if previous_idx is not None:
            total += matrix_value(distance_matrix, previous_idx, current_idx)
        previous_idx = current_idx
    if end_idx is not None and previous_idx is not None:
        total += matrix_value(distance_matrix, previous_idx, end_idx)
    return total


def brute_force_optimize(order_entries, start_idx, end_idx, distance_matrix, duration_matrix, anchor_entry=None):
    """Tenta todas as permutações para encontrar a rota ótima."""
    base_entries = list(order_entries)
    if not base_entries and anchor_entry is None:
        return [], None, None
    best_sequence = None
    best_distance = float('inf')
    best_duration = None
    permutations = itertools.permutations(base_entries) if base_entries else [()]
    for permutation in permutations:
        sequence = []
        if anchor_entry is not None:
            sequence.append(anchor_entry)
        sequence.extend(permutation)
        distance, duration = calculate_route_metrics(sequence, distance_matrix, duration_matrix, start_idx, end_idx)
        if distance is None:
            continue
        if distance + 1e-6 < best_distance:
            best_sequence = sequence
            best_distance = distance
            best_duration = duration
    return best_sequence, best_distance if best_sequence else None, best_duration if best_sequence else None


def apply_two_opt(sequence, start_idx, end_idx, distance_matrix):
    """Aplica otimização 2-opt para reduzir distância total."""
    optimized = list(sequence)
    improved = True
    while improved:
        improved = False
        for i in range(len(optimized) - 1):
            for j in range(i + 2, len(optimized)):
                if j - i == 1:
                    continue
                a_idx = start_idx if i == 0 else optimized[i - 1]['matrix_index']
                d_idx = end_idx if j == len(optimized) - 1 else optimized[j + 1]['matrix_index']
                if a_idx is None or d_idx is None:
                    continue
                b_idx = optimized[i]['matrix_index']
                c_idx = optimized[j]['matrix_index']
                current = (
                    matrix_value(distance_matrix, a_idx, b_idx) +
                    matrix_value(distance_matrix, c_idx, d_idx)
                )
                proposed = (
                    matrix_value(distance_matrix, a_idx, c_idx) +
                    matrix_value(distance_matrix, b_idx, d_idx)
                )
                if proposed + 1e-6 < current:
                    optimized[i:j + 1] = reversed(optimized[i:j + 1])
                    improved = True
        # limita ciclos infinitos
        if not improved:
            break
    return optimized


def calculate_route_metrics(sequence, distance_matrix, duration_matrix, start_idx, end_idx):
    """Calcula métricas totais da rota."""
    total_distance = 0.0
    total_duration = 0.0
    previous_idx = start_idx
    for entry in sequence:
        current_idx = entry['matrix_index']
        if previous_idx is not None:
            total_distance += matrix_value(distance_matrix, previous_idx, current_idx)
            total_duration += matrix_value(duration_matrix, previous_idx, current_idx)
        previous_idx = current_idx
    if end_idx is not None and previous_idx is not None:
        total_distance += matrix_value(distance_matrix, previous_idx, end_idx)
        total_duration += matrix_value(duration_matrix, previous_idx, end_idx)
    if math.isinf(total_distance):
        total_distance = None
    if math.isinf(total_duration):
        total_duration = None
    return total_distance, total_duration


def generate_route_suggestion_orders(orders, route_preferences=None):
    """Gera uma sequência otimizada considerando ponto inicial/final."""
    if not orders:
        return [], {
            'optimized_count': 0,
            'without_coordinates': 0,
            'strategy': 'nearest_neighbor_two_opt',
            'total': 0,
        }

    route_preferences = route_preferences or {}
    start_config = route_preferences.get('start', {})
    end_config = route_preferences.get('end', {})
    geocode_cache = GEOCODE_CACHE

    start_coord = None
    end_coord = None
    if start_config.get('enabled'):
        start_coord = geocode_city_state(start_config.get('cidade'), start_config.get('estado'), geocode_cache)
    if end_config.get('enabled'):
        end_coord = geocode_city_state(end_config.get('cidade'), end_config.get('estado'), geocode_cache)

    orders_with_coords = []
    missing_orders = []
    for order in orders:
        lat = normalize_coordinate_value(order.get('latitude'))
        lon = normalize_coordinate_value(order.get('longitude'))
        if lat is None or lon is None:
            geo_coords = geocode_city_state(order.get('cidade'), order.get('estado'), geocode_cache)
            if geo_coords:
                lat, lon = geo_coords
        if lat is None or lon is None:
            missing_orders.append(order)
            continue
        orders_with_coords.append({
            'order': order,
            'coord': (lat, lon),
        })

    if not orders_with_coords:
        sequence = []
        for position, order in enumerate(orders, start=1):
            order_copy = dict(order)
            order_copy['suggested_position'] = position
            order_copy['suggestion_source'] = 'insufficient_coordinates'
            sequence.append(order_copy)
        return sequence, {
            'optimized_count': 0,
            'without_coordinates': len(missing_orders),
            'strategy': 'sequence_fallback',
            'total': len(orders),
            'start_used': bool(start_coord),
            'end_used': bool(end_coord),
        }

    matrix_points = []
    start_idx = None
    end_idx = None
    if start_coord:
        start_idx = len(matrix_points)
        matrix_points.append(start_coord)
    for entry in orders_with_coords:
        entry['matrix_index'] = len(matrix_points)
        matrix_points.append(entry['coord'])
    if end_coord:
        end_idx = len(matrix_points)
        matrix_points.append(end_coord)

    distance_matrix, duration_matrix, matrix_source = build_distance_duration_matrices(matrix_points)
    anchor_entry = None
    if start_idx is None and orders_with_coords:
        anchor_entry = orders_with_coords[0]
        entries_for_optimization = orders_with_coords[1:]
    else:
        entries_for_optimization = orders_with_coords
    optimized_entries = []
    total_distance = None
    total_duration = None
    strategy_tag = 'heuristic_multi_start'

    total_candidates = len(entries_for_optimization) + (1 if anchor_entry else 0)
    if total_candidates <= MAX_BRUTE_FORCE_ORDERS:
        brute_sequence, brute_distance, brute_duration = brute_force_optimize(
            entries_for_optimization,
            start_idx,
            end_idx,
            distance_matrix,
            duration_matrix,
            anchor_entry=anchor_entry,
        )
        if brute_sequence:
            optimized_entries = brute_sequence
            total_distance = brute_distance
            total_duration = brute_duration
            strategy_tag = 'brute_force_permutation'

    if not optimized_entries:
        optimized_entries = optimize_sequence(entries_for_optimization, start_idx, end_idx, distance_matrix, anchor_entry=anchor_entry)
        total_distance, total_duration = calculate_route_metrics(
            optimized_entries,
            distance_matrix,
            duration_matrix,
            start_idx,
            end_idx,
        )

    suggestion = []
    for position, entry in enumerate(optimized_entries, start=1):
        order_copy = dict(entry['order'])
        order_copy['suggested_position'] = position
        order_copy['suggestion_source'] = 'optimized'
        suggestion.append(order_copy)

    for offset, order in enumerate(missing_orders, start=len(suggestion) + 1):
        order_copy = dict(order)
        order_copy['suggested_position'] = offset
        order_copy['suggestion_source'] = 'missing_coordinates'
        suggestion.append(order_copy)

    meta = {
        'optimized_count': len(optimized_entries),
        'without_coordinates': len(missing_orders),
        'strategy': strategy_tag,
        'total': len(orders),
        'start_used': bool(start_coord),
        'end_used': bool(end_coord),
        'distance_source': matrix_source,
    }
    if total_distance is not None:
        meta['total_distance_km'] = round(total_distance, 2)
    if total_duration is not None:
        meta['total_duration_minutes'] = round(total_duration, 1)

    return suggestion, meta


def format_currency_brl(value):
    """Formata valores numéricos no padrão de moeda brasileira."""
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = 0.0
    return f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def format_decimal_br(value, decimals=2):
    """Formata valores numéricos no padrão brasileiro com casas decimais configuráveis."""
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = 0.0
    format_pattern = f"{{:,.{decimals}f}}"
    return format_pattern.format(value).replace(",", "X").replace(".", ",").replace("X", ".")


app.jinja_env.filters["format_currency_brl"] = format_currency_brl
app.jinja_env.filters["format_decimal_br"] = format_decimal_br



def normalize_lookup_code(value):
    """Normaliza códigos alfanuméricos para comparação consistente."""
    if value is None:
        return ''
    return str(value).strip().upper()


def get_technical_assistance_status_label(value):
    """Retorna a descrição amigável do status da assistência técnica."""
    normalized = normalize_lookup_code(value)
    if not normalized:
        return 'Não Informado'
    return TECHNICAL_ASSISTANCE_STATUS_LABELS.get(normalized, normalized.title())


def get_technical_assistance_situation_label(value):
    """Retorna a descrição amigável da situação da assistência técnica."""
    normalized = normalize_lookup_code(value)
    if not normalized:
        return 'Não Informada'
    return TECHNICAL_ASSISTANCE_SITUATION_LABELS.get(normalized, normalized.title())


def count_business_days(year, months=None):
    """Calcula o número de dias úteis (segunda a sexta) para o ano e meses informados."""
    total = 0
    months = months or range(1, 13)
    for m in months:
        try:
            _, days_in_month = calendar.monthrange(year, m)
        except calendar.IllegalMonthError:
            continue
        for day in range(1, days_in_month + 1):
            if datetime.date(year, m, day).weekday() < 5:
                total += 1
    return total

def get_erp_db_connection():
    """
    Estabelece e retorna uma conexão com o banco de dados PostgreSQL do ERP.
    """
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT
        )
        return conn
    except (Error, UnicodeDecodeError) as e:
        print(f"Erro ao conectar ao banco de dados PostgreSQL do ERP: {e}")
        # flash(f"Erro ao conectar ao banco de dados do ERP: {e}", "danger") # Removido flash em função de conexão
        return None

def get_siga_db_connection():
    """
    Estabelece e retorna uma conexão com o banco de dados PostgreSQL auxiliar (siga_db).
    """
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST, # Assume o mesmo host do ERP, mas com DB diferente
            database=SIGA_DB_NAME,
            user=DB_USER, # Assume o mesmo usuário do ERP, mas pode ser diferente
            password=DB_PASS, # Assume a mesma senha do ERP, mas pode ser diferente
            port=DB_PORT
        )
        return conn
    except (Error, UnicodeDecodeError) as e:
        print(f"Erro ao conectar ao banco de dados auxiliar SIGA_DB: {e}")
        # flash(f"Erro ao conectar ao banco de dados auxiliar: {e}", "danger") # Removido flash em função de conexão
        return None

def init_siga_db():
    """
    Inicializa o banco de dados auxiliar, criando a tabela de usuários e parâmetros se elas não existirem.
    """
    conn = get_siga_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            # Cria a tabela de usuários
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(80) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL
                );
            """)
            # Garante que o campo de hash de senha suporte valores maiores gerados pelos algoritmos atuais
            cur.execute("""
                ALTER TABLE users
                ALTER COLUMN password_hash TYPE VARCHAR(255)
            """)
            # Cria a tabela de parâmetros de usuário
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {USER_PARAMETERS_TABLE} (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    param_name VARCHAR(100) NOT NULL,
                    param_value TEXT,
                    UNIQUE(user_id, param_name),
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                );
            """)
            conn.commit()
            cur.close()
            print("Tabelas 'users' e 'user_parameters' verificadas/criadas com sucesso no siga_db.")
        except Error as e:
            print(f"Erro ao inicializar o siga_db: {e}")
            # flash(f"Erro ao inicializar o banco de dados auxiliar: {e}", "danger") # Removido flash em init_siga_db
        finally:
            if conn:
                conn.close()

# Chama a função de inicialização do banco de dados auxiliar ao iniciar a aplicação
with app.app_context():
    init_siga_db()

def login_required(f):
    """
    Decorador para proteger rotas, exigindo que o usuário esteja logado.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            flash('Você precisa fazer login para acessar esta página.', 'danger')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
        # Em um ambiente de produção, você também verificaria a validade da sessão, etc.
    return decorated_function

def get_user_parameters(user_id, param_name):
    """
    Busca um parâmetro específico para um usuário.
    Retorna o valor do parâmetro ou None se não encontrado.
    """
    conn = get_siga_db_connection()
    param_value = None
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(f"SELECT param_value FROM {USER_PARAMETERS_TABLE} WHERE user_id = %s AND param_name = %s", (user_id, param_name))
            result = cur.fetchone()
            if result:
                param_value = result[0]
            cur.close()
        except Error as e:
            print(f"Erro ao buscar parâmetro '{param_name}' para o usuário {user_id}: {e}")
            # flash(f"Erro ao buscar parâmetro: {e}", "danger") # Removido flash em get_user_parameters
        finally:
            if conn:
                conn.close()
    return param_value

def save_user_parameters(user_id, param_name, param_value):
    """
    Salva ou atualiza um parâmetro para um usuário.
    """
    conn = get_siga_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            # Tenta atualizar o registro existente
            update_query = (
                f"UPDATE {USER_PARAMETERS_TABLE} SET param_value = %s "
                "WHERE user_id = %s AND param_name = %s"
            )
            cur.execute(update_query, (param_value, user_id, param_name))

            # Se nenhuma linha foi atualizada, insere um novo registro
            if cur.rowcount == 0:
                insert_query = (
                    f"INSERT INTO {USER_PARAMETERS_TABLE} "
                    "(user_id, param_name, param_value) VALUES (%s, %s, %s)"
                )
                cur.execute(insert_query, (user_id, param_name, param_value))

            conn.commit()
            cur.close()
            return True
        except Error as e:
            print(f"Erro ao salvar parâmetro '{param_name}' para o usuário {user_id}: {e}")
            flash(f"Erro ao salvar parâmetros: {e}", "danger") # Manter flash aqui, pois ocorre em contexto de requisição
            return False
        finally:
            if conn:
                conn.close()
    return False


def _is_subpath(child_path, parent_path):
    """Verifica se child_path está contido dentro de parent_path."""
    if not child_path or not parent_path:
        return False
    try:
        child_path.relative_to(parent_path)
        return True
    except ValueError:
        return False


def _encode_media_token(value):
    """Codifica o nome do arquivo em um token seguro para URLs."""
    if value is None:
        return ''
    raw_bytes = str(value).encode('utf-8')
    return base64.urlsafe_b64encode(raw_bytes).decode('ascii').rstrip('=')


def _decode_media_token(token):
    """Decodifica o token para recuperar o nome original do arquivo."""
    if not token:
        return None
    padding = '=' * (-len(token) % 4)
    try:
        decoded = base64.urlsafe_b64decode(token + padding)
        return decoded.decode('utf-8')
    except (ValueError, UnicodeDecodeError):
        return None


def _get_media_kind_from_extension(extension):
    """Classifica o tipo de mídia a partir da extensão do arquivo."""
    ext = (extension or '').lower()
    if ext in ASSISTANCE_MEDIA_IMAGE_EXTENSIONS:
        return 'image'
    if ext in ASSISTANCE_MEDIA_VIDEO_EXTENSIONS:
        return 'video'
    if ext in ASSISTANCE_MEDIA_PDF_EXTENSIONS:
        return 'pdf'
    return None


def get_assistance_media_base_path():
    """
    Recupera o caminho base configurado para armazenamento das mídias das assistências.
    """
    user_id = session.get('user_id')
    if not user_id:
        return None, 'Usuário não autenticado.'
    raw_path = get_user_parameters(user_id, ASSISTANCE_MEDIA_PATH_PARAM)
    normalized_path = (raw_path or '').strip()
    if not normalized_path:
        return None, 'O caminho das mídias não foi configurado nos Parâmetros do Sistema.'
    base_path = Path(normalized_path).expanduser()
    try:
        base_path = base_path.resolve()
    except (FileNotFoundError, OSError):
        base_path = base_path
    if not base_path.exists():
        return None, f"O caminho configurado para as mídias ({normalized_path}) não foi encontrado no servidor."
    if not base_path.is_dir():
        return None, f"O caminho configurado para as mídias ({normalized_path}) não é um diretório válido."
    return base_path, None


def resolve_assistance_media_directory(assistance_identifier):
    """
    Resolve o diretório configurado para as mídias de uma assistência específica.
    """
    base_path, error = get_assistance_media_base_path()
    if error:
        return None, None, error

    assistance_code = str(assistance_identifier or '').strip()
    if not assistance_code:
        return base_path, None, 'Assistência inválida.'

    try:
        assistance_dir = (base_path / assistance_code).resolve(strict=False)
    except (RuntimeError, OSError):
        assistance_dir = base_path / assistance_code

    if not _is_subpath(assistance_dir, base_path):
        return base_path, None, 'Caminho de mídia inválido.'

    return base_path, assistance_dir, None


def build_assistance_media_payload(assistance_dir, assistance_identifier):
    """
    Monta a lista de mídias disponíveis para a assistência informada.
    """
    media_files = []
    if not assistance_dir or not assistance_dir.exists() or not assistance_dir.is_dir():
        return media_files

    try:
        entries = sorted(assistance_dir.iterdir(), key=lambda path: path.name.lower())
    except OSError:
        return media_files

    for entry in entries:
        if not entry.is_file():
            continue
        media_kind = _get_media_kind_from_extension(entry.suffix)
        if not media_kind:
            continue
        token = _encode_media_token(entry.name)
        file_size = None
        try:
            file_size = entry.stat().st_size
        except OSError:
            file_size = None
        file_url = url_for(
            'technical_assistance_media_file',
            assistance_identifier=assistance_identifier,
            token=token,
        )
        media_files.append(
            {
                'id': token,
                'name': entry.name,
                'extension': (entry.suffix or '').lower(),
                'kind': media_kind,
                'size': file_size,
                'url': file_url,
                'thumbnail_url': file_url,
            }
        )
    return media_files


def parse_transaction_signs(signs_str):
    """Converte string de sinais ('123:+,456:-') em dicionário."""
    signs = {}
    if signs_str:
        for item in signs_str.split(','):
            if ':' in item:
                code, sign = item.split(':', 1)
                code = code.strip()
                sign = sign.strip()
                if sign not in ['+', '-']:
                    sign = '+'
                signs[code] = sign
    return signs


@app.route('/login', methods=['GET', 'POST'])
def login():
    """
    Rota para a tela de login.
    Lida com a exibição do formulário e o processamento da autenticação.
    """
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_siga_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT id, username, password_hash FROM users WHERE username = %s", (username,))
                user = cur.fetchone()
                cur.close()
                conn.close()

                if user and check_password_hash(user[2], password): # user[2] é o password_hash
                    session['logged_in'] = True
                    session['username'] = user[1] # user[1] é o username
                    session['user_id'] = user[0] # Armazena o ID do usuário na sessão
                    flash('Login realizado com sucesso!', 'success')
                    return redirect(url_for('dashboard'))
                else:
                    flash('Usuário ou senha inválidos.', 'danger')
            except Error as e:
                print(f"Erro ao autenticar usuário: {e}")
                flash(f"Erro ao autenticar: {e}", "danger")
            finally:
                if conn:
                    conn.close()
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    """
    Rota para o cadastro de novos usuários.
    """
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        confirm_password = request.form['confirm_password']

        if not username or not password or not confirm_password:
            flash('Todos os campos são obrigatórios.', 'warning')
            return render_template('register.html')

        if password != confirm_password:
            flash('As senhas não coincidem.', 'danger')
            return render_template('register.html')

        hashed_password = generate_password_hash(password)

        conn = get_siga_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("INSERT INTO users (username, password_hash) VALUES (%s, %s)", (username, hashed_password))
                conn.commit()
                cur.close()
                flash('Usuário cadastrado com sucesso! Faça login para continuar.', 'success')
                return redirect(url_for('login'))
            except psycopg2.IntegrityError: # Erro de violação de unicidade (username já existe)
                flash('Nome de usuário já existe. Por favor, escolha outro.', 'danger')
            except Error as e:
                print(f"Erro ao cadastrar usuário: {e}")
                flash(f"Erro ao cadastrar usuário: {e}", "danger")
            finally:
                if conn:
                    conn.close()
    return render_template('register.html')

@app.route('/')
def home():
    """
    Rota inicial que redireciona para o dashboard se logado, ou para o login.
    """
    if 'logged_in' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """
    Rota para o dashboard principal do sistema.
    """
    sales_summary = get_dashboard_sales_summary()
    return render_template(
        'dashboard.html',
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
        dashboard_sales_summary=sales_summary,
    )

def get_product_line(group_name):
    """
    Função para determinar a linha de produto com base no nome do grupo,
    replicando a lógica DAX fornecida.
    """
    group_name_upper = group_name.upper() if group_name else ""

    if "MADRESILVA" in group_name_upper or "* M." in group_name_upper:
        return "MADRESILVA"
    elif "PETRA" in group_name_upper or "* P." in group_name_upper:
        return "PETRA"
    elif "GARLAND" in group_name_upper or "* G." in group_name_upper:
        return "GARLAND"
    elif "GLASS" in group_name_upper or "* V." in group_name_upper:
        return "GLASSMADRE"
    elif "CAVILHAS" in group_name_upper:
        return "CAVILHAS"
    elif "SOLARE" in group_name_upper or "* S." in group_name_upper:
        return "SOLARE"
    elif "ESPUMA" in group_name_upper or "* ESPUMA" in group_name_upper:
        return "ESPUMA"
    else:
        return "OUTROS"

def get_distinct_product_lines():
    """
    Busca todas as linhas de produto distintas do ERP.
    """
    conn = get_erp_db_connection()
    product_lines = set()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT grunome FROM grupo;")
            group_names = cur.fetchall()
            cur.close()
            for name_tuple in group_names:
                product_lines.add(get_product_line(name_tuple[0]))
        except Error as e:
            print(f"Erro ao buscar linhas de produto distintas: {e}")
        finally:
            if conn:
                conn.close()
    return sorted(list(product_lines))

def get_distinct_states():
    """Busca todos os estados distintos presentes no ERP."""
    conn = get_erp_db_connection()
    states = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT DISTINCT estado FROM cidade ORDER BY estado;")
            states = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar estados distintos: {e}')
        finally:
            conn.close()
    return states

def get_distinct_cities():
    """Busca todas as cidades distintas presentes no ERP."""
    conn = get_erp_db_connection()
    cities = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT DISTINCT cidnome FROM cidade ORDER BY cidnome;")
            cities = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar cidades distintas: {e}')
        finally:
            conn.close()
    return cities

def get_distinct_production_lots():
    """Busca todos os lotes de producao disponiveis no ERP."""
    conn = get_erp_db_connection()
    production_lots = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT lotcod, COALESCE(lotdes, '')
                FROM loteprod
                ORDER BY lotcod DESC, COALESCE(lotdes, '') DESC
                """
            )
            rows = cur.fetchall()
            cur.close()
            for lotcod, lotdes in rows:
                code = str(lotcod) if lotcod is not None else ''
                description = lotdes or ''
                production_lots.append(
                    {
                        'code': code,
                        'description': description,
                    }
                )
        except Error as e:
            print(f'Erro ao buscar lotes de producao distintos: {e}')
        finally:
            if conn:
                conn.close()
    return production_lots


def get_distinct_load_lots():
    """Busca todos os lotes de carga disponiveis no ERP."""
    conn = get_erp_db_connection()
    load_lots = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT lcacod, COALESCE(lcades, '')
                FROM lotecar
                ORDER BY lcacod DESC, COALESCE(lcades, '') DESC
                """
            )
            rows = cur.fetchall()
            cur.close()
            for lcacod, lcades in rows:
                code = str(lcacod) if lcacod is not None else ''
                description = lcades or ''
                load_lots.append(
                    {
                        'code': code,
                        'description': description,
                    }
                )
        except Error as e:
            print(f'Erro ao buscar lotes de carga distintos: {e}')
        finally:
            if conn:
                conn.close()
    return load_lots

def get_distinct_vendors():
    """Busca todos os vendedores distintos e seus status presentes no ERP."""
    conn = get_erp_db_connection()
    vendors = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT DISTINCT vennome, venstatus FROM vendedor ORDER BY vennome;"
            )
            vendors = [
                (row[0], row[1]) for row in cur.fetchall() if row[0]
            ]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar vendedores distintos: {e}')
        finally:
            conn.close()
    return vendors

def get_sales_order_vendors():
    """
    Retorna os vendedores relacionados a pedidos de venda com seus respectivos c�digos.
    """
    conn = get_erp_db_connection()
    vendor_options = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT DISTINCT
                    COALESCE(v.vendedor::text, '') AS vendedor_codigo,
                    COALESCE(v.vennome, '') AS vendedor_nome
                FROM pedido p
                LEFT JOIN vendedor v ON v.vendedor = p.pedrepres
                WHERE p.pedrepres IS NOT NULL
                ORDER BY COALESCE(v.vennome, ''), COALESCE(v.vendedor::text, '')
                """
            )
            rows = cur.fetchall()
            cur.close()
            for code, name in rows:
                vendor_options.append(
                    {
                        'code': code or '',
                        'name': name or '',
                    }
                )
        except Error as e:
            print(f'Erro ao buscar vendedores de pedidos de venda: {e}')
        finally:
            conn.close()
    return vendor_options


def get_sales_order_customers():
    """Retorna clientes presentes em pedidos de venda com seus códigos."""
    conn = get_erp_db_connection()
    customer_options = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT DISTINCT
                    COALESCE(e.empresa::text, '') AS customer_code,
                    COALESCE(e.empnome, '') AS customer_name
                FROM pedido p
                LEFT JOIN empresa e ON e.empresa = p.pedcliente
                WHERE p.pedcliente IS NOT NULL
                ORDER BY COALESCE(e.empnome, ''), COALESCE(e.empresa::text, '')
                """
            )
            for code, name in cur.fetchall():
                customer_options.append(
                    {
                        'code': code or '',
                        'name': name or '',
                    }
                )
            cur.close()
        except Error as e:
            print(f'Erro ao buscar clientes de pedidos de venda: {e}')
        finally:
            conn.close()
    return customer_options


def get_sales_order_transactions():
    """Retorna as transações cadastradas para uso em filtros de pedidos."""
    conn = get_erp_db_connection()
    transaction_options = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT transacao, trsnome FROM transa ORDER BY trsnome;")
            for code, name in cur.fetchall():
                normalized_code = (str(code).strip() if code is not None else '')
                transaction_options.append(
                    {
                        'code': normalized_code,
                        'label': (name or '').strip(),
                    }
                )
            cur.close()
        except Error as e:
            print(f'Erro ao buscar transações comerciais: {e}')
        finally:
            conn.close()
    return transaction_options

def fetch_load_lots_summary(start_date=None, end_date=None):
    """Busca as informacoes agregadas dos lotes de carga, aplicando filtros opcionais de data."""
    load_lots = []
    error_message = None
    conn = get_erp_db_connection()

    if not conn:
        return load_lots, "Nao foi possivel conectar ao banco de dados do ERP."

    try:
        pedprodu_columns = get_table_columns(conn, 'pedprodu')
        has_pprdescped = 'pprdescped' in pedprodu_columns if pedprodu_columns is not None else False
        desconto_expr = (
            "SUM(COALESCE(pp.pprdescped, 0)) AS desconto_total"
            if has_pprdescped else
            "0 AS desconto_total"
        )

        date_filters = []
        params = []
        if start_date:
            date_filters.append("lc.lcaprev >= %s")
            params.append(start_date)
        if end_date:
            date_filters.append("lc.lcaprev <= %s")
            params.append(end_date)

        where_clause = f"WHERE {' AND '.join(date_filters)}" if date_filters else ''

        cur = conn.cursor()
        query = f"""
            WITH lot_items AS (
                SELECT
                    CAST(p.lcapecod AS TEXT) AS lot_code,
                    SUM(COALESCE(pp.pprquanti, 0)) AS quantidade_total,
                    SUM(COALESCE(pp.pprvlsoma, 0)) AS valor_bruto_total,
                    {desconto_expr}
                FROM pedido p
                JOIN pedprodu pp ON pp.pedido = p.pedido
                WHERE p.lcapecod IS NOT NULL
                GROUP BY CAST(p.lcapecod AS TEXT)
            )
            SELECT
                CAST(lc.lcacod AS TEXT) AS lot_code,
                COALESCE(lc.lcades, '') AS description,
                lc.lcaprev,
                COALESCE(lc.lcam3, 0) AS total_m3,
                COALESCE(li.quantidade_total, 0) AS quantidade_total,
                COALESCE(li.valor_bruto_total, 0) - COALESCE(li.desconto_total, 0) AS valor_total
            FROM lotecar lc
            LEFT JOIN lot_items li ON li.lot_code = CAST(lc.lcacod AS TEXT)
            {where_clause}
            ORDER BY COALESCE(lc.lcaprev, '1900-01-01') DESC, CAST(lc.lcacod AS TEXT) DESC
        """
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            load_lots.append(
                {
                    'codigo': row[0] or '',
                    'descricao': (row[1] or '').strip(),
                    'previsao': row[2],
                    'total_m3': float(row[3] or 0),
                    'quantidade_total': float(row[4] or 0),
                    'valor_total': float(row[5] or 0),
                }
            )
    except Error as e:
        error_message = f"Erro ao buscar lotes de carga: {e}"
    finally:
        if conn:
            conn.close()

    return load_lots, error_message

def fetch_load_lot_orders(load_lot_code):
    """Lista os pedidos associados a um lote de carga."""
    orders = []
    lot_info = None
    error_message = None

    if not load_lot_code:
        return orders, lot_info, error_message

    conn = get_erp_db_connection()
    if not conn:
        return orders, lot_info, "Nao foi possivel conectar ao banco de dados do ERP."

    try:
        pedprodu_columns = get_table_columns(conn, 'pedprodu')
        cidade_columns = get_table_columns(conn, 'cidade')
        has_pprdescped = 'pprdescped' in pedprodu_columns if pedprodu_columns is not None else False
        desconto_expr = (
            "SUM(COALESCE(pp.pprdescped, 0)) AS desconto_total"
            if has_pprdescped else
            "0 AS desconto_total"
        )
        latitude_column = None
        longitude_column = None
        if cidade_columns:
            for candidate in ('cidlatitude', 'latitude', 'cidlat', 'latitude_gps'):
                if candidate in cidade_columns:
                    latitude_column = candidate
                    break
            for candidate in ('cidlongitude', 'longitude', 'cidlong', 'longitude_gps'):
                if candidate in cidade_columns:
                    longitude_column = candidate
                    break

        latitude_select = f"COALESCE(c.{latitude_column}, 0) AS cidade_latitude," if latitude_column else "NULL AS cidade_latitude,"
        longitude_select = f"COALESCE(c.{longitude_column}, 0) AS cidade_longitude," if longitude_column else "NULL AS cidade_longitude,"

        cur = conn.cursor()
        query = f"""
            WITH order_items AS (
                SELECT
                    pedido,
                    SUM(COALESCE(pprquanti, 0)) AS quantidade_total,
                    SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total,
                    {desconto_expr}
                FROM pedprodu
                GROUP BY pedido
            ),
            lot_totals AS (
                SELECT
                    CAST(p.lcapecod AS TEXT) AS lot_code,
                    SUM(COALESCE(pp.pprquanti, 0)) AS quantidade_total
                FROM pedido p
                JOIN pedprodu pp ON pp.pedido = p.pedido
                WHERE p.lcapecod IS NOT NULL
                GROUP BY CAST(p.lcapecod AS TEXT)
            )
            SELECT
                CAST(p.pedido AS TEXT) AS pedido,
                COALESCE(p.lcaseque::text, '') AS sequencia,
                COALESCE(e.empnome, '') AS cliente,
                COALESCE(c.cidnome, '') AS cidade,
                COALESCE(
                    NULLIF(TRIM(c.estado), ''),
                    NULLIF(TRIM(p.pedentuf::text), '')
                ) AS estado,
                {latitude_select}
                {longitude_select}
                COALESCE(oi.quantidade_total, 0) AS quantidade_total,
                CASE
                    WHEN COALESCE(lt.quantidade_total, 0) > 0 THEN
                        (COALESCE(oi.quantidade_total, 0) / lt.quantidade_total) * COALESCE(lc.lcam3, 0)
                    ELSE 0
                END AS total_m3,
                COALESCE(oi.valor_bruto_total, 0) - COALESCE(oi.desconto_total, 0) AS valor_total
            FROM pedido p
            LEFT JOIN order_items oi ON oi.pedido = p.pedido
            LEFT JOIN empresa e ON e.empresa = p.pedcliente
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN lotecar lc ON lc.lcacod = p.lcapecod
            LEFT JOIN lot_totals lt ON lt.lot_code = CAST(p.lcapecod AS TEXT)
            WHERE CAST(p.lcapecod AS TEXT) = %s
            ORDER BY p.pedido DESC
        """
        cur.execute(query, (load_lot_code,))
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            orders.append(
                {
                    'pedido': row[0],
                    'sequencia': row[1],
                    'cliente': row[2],
                    'quantidade_total': float(row[7] or 0),
                    'total_m3': float(row[8] or 0),
                    'valor_total': float(row[9] or 0),
                    'cidade': (row[3] or '').strip(),
                    'estado': (row[4] or '').strip(),
                    'latitude': float(row[5]) if row[5] not in (None, '') else None,
                    'longitude': float(row[6]) if row[6] not in (None, '') else None,
                }
            )

        info_cur = conn.cursor()
        info_cur.execute(
            """
            SELECT
                CAST(lcacod AS TEXT) AS codigo,
                COALESCE(lcades, '') AS descricao,
                lcaprev,
                COALESCE(lcam3, 0) AS total_m3
            FROM lotecar
            WHERE CAST(lcacod AS TEXT) = %s
            """,
            (load_lot_code,)
        )
        info_row = info_cur.fetchone()
        info_cur.close()

        if info_row:
            lot_info = {
                'codigo': info_row[0],
                'descricao': (info_row[1] or '').strip(),
                'previsao': info_row[2],
                'total_m3': float(info_row[3] or 0),
            }
    except Error as e:
        error_message = f"Erro ao buscar pedidos do lote {load_lot_code}: {e}"
    finally:
        if conn:
            conn.close()

    return orders, lot_info, error_message

def get_distinct_occurrences():
    """
    Retorna as ocorr�ncias cadastradas no acompanhamento de pedidos.
    """
    conn = get_erp_db_connection()
    occurrences = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT
                    COALESCE(peds1oco::text, '') AS occurrence_code,
                    COALESCE(peds1doco, '') AS occurrence_description
                FROM acompanh
                ORDER BY occurrence_code, occurrence_description
                """
            )
            raw_rows = cur.fetchall()
            cur.close()
            occurrence_map = {}
            for code_raw, description_raw in raw_rows:
                code = (code_raw or '').strip()
                description = (description_raw or '').strip()
                bucket = occurrence_map.setdefault(code, set())
                if description:
                    bucket.add(description)
                elif not bucket:
                    bucket.add('')

            def pick_best_description(descriptions):
                if not descriptions:
                    return ''
                def score(text):
                    cleaned = (text or '').strip()
                    if not cleaned:
                        return (0, 0, 0, 0, '')
                    has_letters = 1 if any(ch.isalpha() for ch in cleaned) else 0
                    has_space = 1 if ' ' in cleaned else 0
                    has_slash = 1 if '/' in cleaned else 0
                    length = len(cleaned)
                    return (has_letters, has_space, has_slash, length, cleaned)
                return max(descriptions, key=score)

            occurrences = [
                {
                    'code': code,
                    'description': pick_best_description(occurrence_map[code]),
                }
                for code in sorted(occurrence_map.keys())
                if code or occurrence_map[code]
            ]
            occurrences.insert(
                0,
                {
                    'code': OCCURRENCE_BLANK_VALUE,
                    'description': 'Em branco',
                },
            )
        except Error as e:
            print(f'Erro ao buscar ocorr�ncias de pedidos: {e}')
        finally:
            conn.close()
    return occurrences


def get_distinct_vendor_statuses():
    """Busca todos os status de vendedores distintos presentes no ERP."""
    conn = get_erp_db_connection()
    statuses = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT DISTINCT venstatus FROM vendedor ORDER BY venstatus;"
            )
            statuses = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar status de vendedores: {e}')
        finally:
            conn.close()
    return statuses

def fetch_monthly_revenue(year, filters):
    """Retorna o faturamento mensal para o ano especificado.

    Esta função executa uma consulta agregada no ERP e pode aplicar
    filtros opcionais de mês, estado, cidade, vendedor, linha de produto e CFOP.
    """
    conn = get_erp_db_connection()
    monthly_totals = [0.0] * 12

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_comparison'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT EXTRACT(MONTH FROM tm.pridata) AS mes,
                       SUM(tm.privltotal) AS total,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                LEFT JOIN vendedor v ON d.vennome = v.vennome
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [year]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue

                if valid_months:
                    placeholders = ','.join(['%s'] * len(valid_months))
                    sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                    params.extend(valid_months)
            states = filters.get('state')
            if states:
                placeholders = ','.join(['%s'] * len(states))
                sql += f' AND c.estado IN ({placeholders})'
                params.extend(states)

            cities = filters.get('city')
            if cities:
                placeholders = ','.join(['%s'] * len(cities))
                sql += f" AND c.cidnome IN ({placeholders})"
                params.extend(cities)

            vendors = filters.get('vendor')
            if vendors:
                placeholders = ','.join(['%s'] * len(vendors))
                sql += f" AND d.vennome IN ({placeholders})"
                params.extend(vendors)

            vendor_statuses = filters.get('vendor_status')
            if vendor_statuses:
                placeholders = ','.join(['%s'] * len(vendor_statuses))
                sql += f" AND v.venstatus IN ({placeholders})"
                params.extend(vendor_statuses)

            lines = filters.get('line')
            if lines:
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) in lines:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)
            # Quando nenhum parametro de transacao e definido pelo usuario o
            # filtro nao e aplicado para permitir a exibicao de dados

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY mes, op.opetransac ORDER BY mes"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            for mes, total, transac in results:
                idx = int(mes) - 1
                sign = transaction_signs.get(str(transac), '+')
                if sign == '-':
                    monthly_totals[idx] -= float(total)
                else:
                    monthly_totals[idx] += float(total)
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento mensal: {e}')
        finally:
            conn.close()

    return monthly_totals


def fetch_monthly_sales_orders(year, filters):
    """Retorna o valor total mensal dos pedidos de venda para o ano informado."""
    conn = get_erp_db_connection()
    monthly_totals = [0.0] * 12

    if not conn:
        return monthly_totals

    try:
        cur = conn.cursor()
        has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')
        valor_total_expression = (
            "COALESCE(pedprod.valor_bruto_total, 0) - COALESCE(p.peddesval, 0)"
            if has_peddesval_column else
            "COALESCE(pedprod.valor_bruto_total, 0)"
        )

        state_expression = (
            "CASE "
            "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
            "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
            "ELSE '' "
            "END"
        )

        line_case_expression = (
            "CASE "
            "WHEN POSITION('MADRESILVA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* M.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'MADRESILVA' "
            "WHEN POSITION('PETRA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* P.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'PETRA' "
            "WHEN POSITION('GARLAND' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* G.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GARLAND' "
            "WHEN POSITION('GLASS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* V.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GLASSMADRE' "
            "WHEN POSITION('CAVILHAS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'CAVILHAS' "
            "WHEN POSITION('SOLARE' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* S.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'SOLARE' "
            "WHEN POSITION('ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'ESPUMA' "
            "ELSE 'OUTROS' "
            "END"
        )

        query = f"""
            WITH pedprod AS (
                SELECT
                    pedido,
                    SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total
                FROM pedprodu
                GROUP BY pedido
            )
            SELECT
                EXTRACT(MONTH FROM p.peddata) AS mes,
                SUM({valor_total_expression}) AS total
            FROM pedido p
            LEFT JOIN pedprod ON pedprod.pedido = p.pedido
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN empresa cli ON cli.empresa = p.pedcliente
            LEFT JOIN opera op ON op.operacao = p.pedoperaca
            WHERE p.peddata IS NOT NULL
              AND EXTRACT(YEAR FROM p.peddata) = %s
        """
        params = [year]

        months = filters.get('month')
        if months:
            month_values = []
            for month in months:
                try:
                    month_int = int(month)
                except (TypeError, ValueError):
                    continue
                if 1 <= month_int <= 12:
                    month_values.append(month_int)
            if month_values:
                placeholders = ','.join(['%s'] * len(month_values))
                query += f" AND EXTRACT(MONTH FROM p.peddata) IN ({placeholders})"
                params.extend(month_values)

        vendors = filters.get('vendor')
        if vendors:
            vendor_values = [str(v).strip() for v in vendors if str(v).strip()]
            if vendor_values:
                placeholders = ','.join(['%s'] * len(vendor_values))
                query += f" AND CAST(p.pedrepres AS TEXT) IN ({placeholders})"
                params.extend(vendor_values)

        states = filters.get('state')
        if states:
            state_values = [str(s).strip() for s in states if str(s).strip()]
            if state_values:
                placeholders = ','.join(['%s'] * len(state_values))
                query += f" AND {state_expression} IN ({placeholders})"
                params.extend(state_values)

        statuses = filters.get('status')
        if statuses:
            status_values = [str(s).strip().upper() for s in statuses if str(s).strip()]
            if status_values:
                placeholders = ','.join(['%s'] * len(status_values))
                query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
                params.extend(status_values)

        situations = filters.get('situation')
        if situations:
            situation_values = [str(s).strip().upper() for s in situations if str(s).strip() or s == '']
            if situation_values:
                placeholders = ','.join(['%s'] * len(situation_values))
                query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
                params.extend(situation_values)

        lines = filters.get('line')
        if lines:
            line_values = [str(l).strip().upper() for l in lines if str(l).strip()]
            if line_values:
                placeholders = ','.join(['%s'] * len(line_values))
                query += (
                    f" AND EXISTS ("
                    f"     SELECT 1 FROM pedprodu pp_line"
                    f"     LEFT JOIN produto prod_line ON prod_line.produto = pp_line.pprproduto"
                    f"     LEFT JOIN grupo g ON g.grupo = prod_line.grupo"
                    f"     WHERE pp_line.pedido = p.pedido"
                    f"       AND {line_case_expression} IN ({placeholders})"
                    f" )"
                )
                params.extend(line_values)

        customers = filters.get('customer')
        if customers:
            customer_values = [str(c).strip() for c in customers if str(c).strip()]
            if customer_values:
                placeholders = ','.join(['%s'] * len(customer_values))
                query += f" AND CAST(p.pedcliente AS TEXT) IN ({placeholders})"
                params.extend(customer_values)

        transactions = filters.get('transaction')
        if transactions:
            transaction_values = [str(t).strip() for t in transactions if str(t).strip()]
            if transaction_values:
                placeholders = ','.join(['%s'] * len(transaction_values))
                query += f" AND COALESCE(op.opetransac::text, '') IN ({placeholders})"
                params.extend(transaction_values)

        query += " GROUP BY EXTRACT(MONTH FROM p.peddata)"
        cur.execute(query, params)

        for month, total in cur.fetchall():
            try:
                month_idx = int(month)
            except (TypeError, ValueError):
                continue
            if 1 <= month_idx <= 12:
                monthly_totals[month_idx - 1] = float(total or 0)

        cur.close()
    except Error as e:
        print(f"Erro ao buscar totais mensais de pedidos de venda: {e}")
    finally:
        conn.close()

    return monthly_totals


def fetch_orders_by_representative(filters):
    """Retorna o valor total dos pedidos agrupado por representante."""
    conn = get_erp_db_connection()
    data = []

    if not conn:
        return data

    try:
        cur = conn.cursor()
        has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')
        valor_total_expression = (
            "COALESCE(pedprod.valor_bruto_total, 0) - COALESCE(p.peddesval, 0)"
            if has_peddesval_column else
            "COALESCE(pedprod.valor_bruto_total, 0)"
        )

        state_expression = (
            "CASE "
            "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
            "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
            "ELSE '' "
            "END"
        )

        line_case_expression = (
            "CASE "
            "WHEN POSITION('MADRESILVA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* M.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'MADRESILVA' "
            "WHEN POSITION('PETRA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* P.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'PETRA' "
            "WHEN POSITION('GARLAND' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* G.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GARLAND' "
            "WHEN POSITION('GLASS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* V.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GLASSMADRE' "
            "WHEN POSITION('CAVILHAS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'CAVILHAS' "
            "WHEN POSITION('SOLARE' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* S.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'SOLARE' "
            "WHEN POSITION('ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'ESPUMA' "
            "ELSE 'OUTROS' "
            "END"
        )

        query = f"""
            WITH pedprod AS (
                SELECT
                    pedido,
                    SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total
                FROM pedprodu
                GROUP BY pedido
            )
            SELECT
                COALESCE(v.vennome, 'Sem Representante') AS representative,
                COALESCE(CAST(p.pedrepres AS TEXT), '') AS representative_code,
                SUM({valor_total_expression}) AS total
            FROM pedido p
            LEFT JOIN pedprod ON pedprod.pedido = p.pedido
            LEFT JOIN vendedor v ON v.vendedor = p.pedrepres
            LEFT JOIN empresa cli ON cli.empresa = p.pedcliente
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN opera op ON op.operacao = p.pedoperaca
            WHERE p.peddata IS NOT NULL
        """
        params = []

        if filters.get('start_date'):
            query += " AND p.peddata >= %s"
            params.append(filters['start_date'])
        if filters.get('end_date'):
            query += " AND p.peddata <= %s"
            params.append(filters['end_date'])

        vendors = filters.get('vendor')
        if vendors:
            vendor_values = [str(v).strip() for v in vendors if str(v).strip()]
            if vendor_values:
                placeholders = ','.join(['%s'] * len(vendor_values))
                query += f" AND CAST(p.pedrepres AS TEXT) IN ({placeholders})"
                params.extend(vendor_values)

        states = filters.get('state')
        if states:
            state_values = [str(s).strip() for s in states if str(s).strip()]
            if state_values:
                placeholders = ','.join(['%s'] * len(state_values))
                query += f" AND {state_expression} IN ({placeholders})"
                params.extend(state_values)

        statuses = filters.get('status')
        if statuses:
            status_values = [str(s).strip().upper() for s in statuses if str(s).strip()]
            if status_values:
                placeholders = ','.join(['%s'] * len(status_values))
                query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
                params.extend(status_values)

        situations = filters.get('situation')
        if situations:
            situation_values = [str(s).strip().upper() for s in situations]
            if situation_values:
                placeholders = ','.join(['%s'] * len(situation_values))
                query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
                params.extend(situation_values)

        lines = filters.get('line')
        if lines:
            line_values = [str(l).strip().upper() for l in lines if str(l).strip()]
            if line_values:
                placeholders = ','.join(['%s'] * len(line_values))
                query += (
                    f" AND EXISTS ("
                    f"     SELECT 1 FROM pedprodu pp_line"
                    f"     LEFT JOIN produto prod_line ON prod_line.produto = pp_line.pprproduto"
                    f"     LEFT JOIN grupo g_line ON g_line.grupo = prod_line.grupo"
                    f"     WHERE pp_line.pedido = p.pedido"
                    f"       AND {line_case_expression} IN ({placeholders})"
                    f" )"
                )
                params.extend(line_values)

        customers = filters.get('customer')
        if customers:
            customer_values = [str(c).strip() for c in customers if str(c).strip()]
            if customer_values:
                placeholders = ','.join(['%s'] * len(customer_values))
                query += f" AND CAST(p.pedcliente AS TEXT) IN ({placeholders})"
                params.extend(customer_values)

        transactions = filters.get('transaction')
        if transactions:
            transaction_values = [str(t).strip() for t in transactions if str(t).strip()]
            if transaction_values:
                placeholders = ','.join(['%s'] * len(transaction_values))
                query += f" AND COALESCE(op.opetransac::text, '') IN ({placeholders})"
                params.extend(transaction_values)

        query += " GROUP BY representative, representative_code ORDER BY total DESC"
        cur.execute(query, params)

        for representative, representative_code, total in cur.fetchall():
            rep_raw = (representative or '').strip()
            rep_name = rep_raw or 'Sem Representante'
            code_text = (str(representative_code) if representative_code is not None else '').strip()
            label = rep_name
            if code_text:
                label = f"{rep_name} ({code_text})"
            data.append({
                'representative': rep_name,
                'representative_code': code_text,
                'label': label,
                'total': float(total or 0),
            })

        cur.close()
    except Error as e:
        print(f'Erro ao buscar pedidos por representante: {e}')
    finally:
        conn.close()

    return data


def fetch_orders_by_state(filters):
    """Retorna o valor total dos pedidos agrupado por estado."""
    conn = get_erp_db_connection()
    data = []

    if not conn:
        return data

    try:
        cur = conn.cursor()
        has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')
        valor_total_expression = (
            "COALESCE(pedprod.valor_bruto_total, 0) - COALESCE(p.peddesval, 0)"
            if has_peddesval_column else
            "COALESCE(pedprod.valor_bruto_total, 0)"
        )

        state_expression = (
            "CASE "
            "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
            "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
            "ELSE '' "
            "END"
        )

        state_label_expression = f"COALESCE(NULLIF({state_expression}, ''), 'Sem Estado')"

        line_case_expression = (
            "CASE "
            "WHEN POSITION('MADRESILVA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* M.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'MADRESILVA' "
            "WHEN POSITION('PETRA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* P.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'PETRA' "
            "WHEN POSITION('GARLAND' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* G.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GARLAND' "
            "WHEN POSITION('GLASS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* V.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GLASSMADRE' "
            "WHEN POSITION('CAVILHAS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'CAVILHAS' "
            "WHEN POSITION('SOLARE' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* S.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'SOLARE' "
            "WHEN POSITION('ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 OR POSITION('* ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'ESPUMA' "
            "ELSE 'OUTROS' "
            "END"
        )

        query = f"""
            WITH pedprod AS (
                SELECT
                    pedido,
                    SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total
                FROM pedprodu
                GROUP BY pedido
            )
            SELECT
                {state_label_expression} AS state,
                SUM({valor_total_expression}) AS total
            FROM pedido p
            LEFT JOIN pedprod ON pedprod.pedido = p.pedido
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN opera op ON op.operacao = p.pedoperaca
            WHERE p.peddata IS NOT NULL
        """
        params = []

        if filters.get('start_date'):
            query += " AND p.peddata >= %s"
            params.append(filters['start_date'])
        if filters.get('end_date'):
            query += " AND p.peddata <= %s"
            params.append(filters['end_date'])

        vendors = filters.get('vendor')
        if vendors:
            vendor_values = [str(v).strip() for v in vendors if str(v).strip()]
            if vendor_values:
                placeholders = ','.join(['%s'] * len(vendor_values))
                query += f" AND CAST(p.pedrepres AS TEXT) IN ({placeholders})"
                params.extend(vendor_values)

        states = filters.get('state')
        if states:
            state_values = [str(s).strip() for s in states if str(s).strip()]
            if state_values:
                placeholders = ','.join(['%s'] * len(state_values))
                query += f" AND {state_expression} IN ({placeholders})"
                params.extend(state_values)

        statuses = filters.get('status')
        if statuses:
            status_values = [str(s).strip().upper() for s in statuses if str(s).strip()]
            if status_values:
                placeholders = ','.join(['%s'] * len(status_values))
                query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
                params.extend(status_values)

        situations = filters.get('situation')
        if situations:
            situation_values = [str(s).strip().upper() for s in situations if s is not None]
            if situation_values:
                placeholders = ','.join(['%s'] * len(situation_values))
                query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
                params.extend(situation_values)

        lines = filters.get('line')
        if lines:
            line_values = [str(l).strip().upper() for l in lines if str(l).strip()]
            if line_values:
                placeholders = ','.join(['%s'] * len(line_values))
                query += (
                    f" AND EXISTS ("
                    f"     SELECT 1 FROM pedprodu pp_line"
                    f"     LEFT JOIN produto prod_line ON prod_line.produto = pp_line.pprproduto"
                    f"     LEFT JOIN grupo g_line ON g_line.grupo = prod_line.grupo"
                    f"     WHERE pp_line.pedido = p.pedido"
                    f"       AND {line_case_expression} IN ({placeholders})"
                    f" )"
                )
                params.extend(line_values)

        customers = filters.get('customer')
        if customers:
            customer_values = [str(c).strip() for c in customers if str(c).strip()]
            if customer_values:
                placeholders = ','.join(['%s'] * len(customer_values))
                query += f" AND CAST(p.pedcliente AS TEXT) IN ({placeholders})"
                params.extend(customer_values)

        transactions = filters.get('transaction')
        if transactions:
            transaction_values = [str(t).strip() for t in transactions if str(t).strip()]
            if transaction_values:
                placeholders = ','.join(['%s'] * len(transaction_values))
                query += f" AND COALESCE(op.opetransac::text, '') IN ({placeholders})"
                params.extend(transaction_values)

        query += f" GROUP BY {state_label_expression}"
        query += " ORDER BY state"

        cur.execute(query, params)

        for state, total in cur.fetchall():
            label = (state or 'Sem Estado')
            data.append({
                'state': label,
                'total': float(total or 0),
            })

        cur.close()
    except Error as e:
        print(f'Erro ao buscar pedidos por estado: {e}')
    finally:
        conn.close()

    return data


def fetch_orders_by_line(filters):
    """Retorna o valor total dos pedidos agrupado por linha."""
    conn = get_erp_db_connection()
    data = []

    if not conn:
        return data

    try:
        cur = conn.cursor()
        has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')
        discount_expression = "COALESCE(p.peddesval, 0)" if has_peddesval_column else "0"

        state_expression = (
            "CASE "
            "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
            "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
            "ELSE '' "
            "END"
        )

        line_case_expression = (
            "CASE "
            "WHEN POSITION('MADRESILVA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* M.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'MADRESILVA' "
            "WHEN POSITION('PETRA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* P.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'PETRA' "
            "WHEN POSITION('GARLAND' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* G.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GARLAND' "
            "WHEN POSITION('GLASS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* V.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'GLASSMADRE' "
            "WHEN POSITION('CAVILHAS' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'CAVILHAS' "
            "WHEN POSITION('SOLARE' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* S.' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'SOLARE' "
            "WHEN POSITION('ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 "
            "     OR POSITION('* ESPUMA' IN UPPER(COALESCE(g_line.grunome, ''))) > 0 THEN 'ESPUMA' "
            "ELSE 'OUTROS' "
            "END"
        )

        query = f"""
            WITH line_values AS (
                SELECT
                    p.pedido,
                    {line_case_expression} AS line,
                    SUM(COALESCE(pp.pprvlsoma, 0)) AS line_total
                FROM pedido p
                LEFT JOIN pedprodu pp ON pp.pedido = p.pedido
                LEFT JOIN produto prod_line ON prod_line.produto = pp.pprproduto
                LEFT JOIN grupo g_line ON g_line.grupo = prod_line.grupo
                LEFT JOIN cidade c ON c.cidade = p.pedentcid
                LEFT JOIN opera op ON op.operacao = p.pedoperaca
                WHERE p.peddata IS NOT NULL
        """
        params = []

        if filters.get('start_date'):
            query += " AND p.peddata >= %s"
            params.append(filters['start_date'])
        if filters.get('end_date'):
            query += " AND p.peddata <= %s"
            params.append(filters['end_date'])

        vendors = filters.get('vendor')
        if vendors:
            vendor_values = [str(v).strip() for v in vendors if str(v).strip()]
            if vendor_values:
                placeholders = ','.join(['%s'] * len(vendor_values))
                query += f" AND CAST(p.pedrepres AS TEXT) IN ({placeholders})"
                params.extend(vendor_values)

        states = filters.get('state')
        if states:
            state_values = [str(s).strip().upper() for s in states if str(s).strip()]
            if state_values:
                placeholders = ','.join(['%s'] * len(state_values))
                query += f" AND {state_expression} IN ({placeholders})"
                params.extend(state_values)

        statuses = filters.get('status')
        if statuses:
            status_values = [str(s).strip().upper() for s in statuses if str(s).strip()]
            if status_values:
                placeholders = ','.join(['%s'] * len(status_values))
                query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
                params.extend(status_values)

        situations = filters.get('situation')
        if situations:
            situation_values = [str(s).strip().upper() for s in situations if s is not None]
            if situation_values:
                placeholders = ','.join(['%s'] * len(situation_values))
                query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
                params.extend(situation_values)

        lines = filters.get('line')
        if lines:
            line_values = [str(l).strip().upper() for l in lines if str(l).strip()]
            if line_values:
                placeholders = ','.join(['%s'] * len(line_values))
                query += f" AND {line_filter_expression} IN ({placeholders})"
                params.extend(line_values)

        customers = filters.get('customer')
        if customers:
            customer_values = [str(c).strip() for c in customers if str(c).strip()]
            if customer_values:
                placeholders = ','.join(['%s'] * len(customer_values))
                query += f" AND COALESCE(p.pedcliente::text, '') IN ({placeholders})"
                params.extend(customer_values)

        transactions = filters.get('transaction')
        if transactions:
            transaction_values = [str(t).strip() for t in transactions if str(t).strip()]
            if transaction_values:
                placeholders = ','.join(['%s'] * len(transaction_values))
                query += f" AND COALESCE(op.opetransac::text, '') IN ({placeholders})"
                params.extend(transaction_values)

        query += f" GROUP BY p.pedido, {line_case_expression}"
        query += """
            ),
            order_totals AS (
                SELECT pedido, SUM(line_total) AS order_total
                FROM line_values
                GROUP BY pedido
            )
            SELECT
                lv.line,
                SUM(
                    lv.line_total
                    - CASE
                        WHEN order_totals.order_total > 0 THEN
                            (""" + discount_expression + """ * lv.line_total / order_totals.order_total)
                        ELSE 0
                      END
                ) AS total
            FROM line_values lv
            LEFT JOIN order_totals ON order_totals.pedido = lv.pedido
            LEFT JOIN pedido p ON p.pedido = lv.pedido
            GROUP BY lv.line
            ORDER BY lv.line
        """

        cur.execute(query, tuple(params))
        for line, total in cur.fetchall():
            data.append({'line': line or 'Sem Linha', 'total': float(total or 0)})
        cur.close()
    except Error as e:
        print(f'Erro ao buscar pedidos por linha: {e}')
    finally:
        conn.close()

    return data


def fetch_decomposition_tree(filters):
    """Retorna as linhas necessárias para montar a árvore de decomposição dos pedidos."""
    conn = get_erp_db_connection()
    data = []

    if not conn:
        return data

    try:
        cur = conn.cursor()
        has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')

        pp_value_expr = "COALESCE(pp.pprvlsoma, 0)"
        order_gross_expression = "COALESCE(pedprod.valor_bruto_total, 0)"
        if has_peddesval_column:
            order_net_expression = f"{order_gross_expression} - COALESCE(p.peddesval, 0)"
        else:
            order_net_expression = order_gross_expression

        ratio_expr = (
            f"CASE WHEN {order_gross_expression} = 0 THEN 0 "
            f"ELSE {pp_value_expr} / NULLIF({order_gross_expression}, 0) END"
        )
        value_expression = f"({order_net_expression}) * {ratio_expr}"

        state_expression = (
            "CASE "
            "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
            "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
            "ELSE '' "
            "END"
        )

        city_expression = (
            "CASE "
            "WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome "
            "WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text "
            "ELSE 'Sem Cidade' "
            "END"
        )

        line_label_expression = (
            "CASE "
            "WHEN POSITION('MADRESILVA' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* M.' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'MADRESILVA' "
            "WHEN POSITION('PETRA' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* P.' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'PETRA' "
            "WHEN POSITION('GARLAND' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* G.' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'GARLAND' "
            "WHEN POSITION('GLASS' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* V.' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'GLASSMADRE' "
            "WHEN POSITION('CAVILHAS' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'CAVILHAS' "
            "WHEN POSITION('SOLARE' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* S.' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'SOLARE' "
            "WHEN POSITION('ESPUMA' IN UPPER(COALESCE(g.grunome, ''))) > 0 "
            "     OR POSITION('* ESPUMA' IN UPPER(COALESCE(g.grunome, ''))) > 0 THEN 'ESPUMA' "
            "ELSE 'OUTROS' "
            "END"
        )
        line_filter_expression = f"UPPER({line_label_expression})"
        sub_group_expression = "COALESCE(NULLIF(subg1.subnome, ''), 'Sem SubGrupo')"
        product_name_expression = "COALESCE(NULLIF(prod.pronome::text, ''), 'Sem Produto')"
        product_code_expression = "COALESCE(prod.produto::text, '')"
        vendor_code_expression = "COALESCE(p.pedrepres::text, '')"
        vendor_name_expression = "COALESCE(v.vennome, '')"
        customer_code_expression = "COALESCE(p.pedcliente::text, '')"
        customer_name_expression = "COALESCE(e.empnome, '')"

        query = f"""
            WITH pedprod AS (
                SELECT pedido, SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total
                FROM pedprodu
                GROUP BY pedido
            )
            SELECT
                {vendor_code_expression} AS vendor_code,
                {vendor_name_expression} AS vendor_name,
                {customer_code_expression} AS customer_code,
                {customer_name_expression} AS customer_name,
                {city_expression} AS city,
                {line_label_expression} AS line,
                {sub_group_expression} AS sub_group,
                {product_name_expression} AS product_name,
                {product_code_expression} AS product_code,
                SUM({value_expression}) AS total_value
            FROM pedido p
            LEFT JOIN pedprodu pp ON pp.pedido = p.pedido
            LEFT JOIN produto prod ON prod.produto = pp.pprproduto
            LEFT JOIN grupo g ON g.grupo = prod.grupo
            LEFT JOIN grupo1 subg1 ON subg1.subgrupo = prod.subgrupo
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN empresa e ON e.empresa = p.pedcliente
            LEFT JOIN vendedor v ON v.vendedor = p.pedrepres
            LEFT JOIN opera op ON op.operacao = p.pedoperaca
            LEFT JOIN pedprod ON pedprod.pedido = p.pedido
            WHERE p.peddata IS NOT NULL
        """
        params = []

        if filters.get('start_date'):
            query += " AND p.peddata >= %s"
            params.append(filters['start_date'])
        if filters.get('end_date'):
            query += " AND p.peddata <= %s"
            params.append(filters['end_date'])

        vendors = filters.get('vendor')
        if vendors:
            vendor_values = [str(v).strip() for v in vendors if str(v).strip()]
            if vendor_values:
                placeholders = ','.join(['%s'] * len(vendor_values))
                query += f" AND {vendor_code_expression} IN ({placeholders})"
                params.extend(vendor_values)

        states = filters.get('state')
        if states:
            state_values = [str(s).strip() for s in states if str(s).strip()]
            if state_values:
                placeholders = ','.join(['%s'] * len(state_values))
                query += f" AND {state_expression} IN ({placeholders})"
                params.extend(state_values)

        customers = filters.get('customer')
        if customers:
            customer_values = [str(c).strip() for c in customers if str(c).strip()]
            if customer_values:
                placeholders = ','.join(['%s'] * len(customer_values))
                query += f" AND {customer_code_expression} IN ({placeholders})"
                params.extend(customer_values)

        statuses = filters.get('status')
        if statuses:
            status_values = [str(s).strip().upper() for s in statuses if str(s).strip()]
            if status_values:
                placeholders = ','.join(['%s'] * len(status_values))
                query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
                params.extend(status_values)

        situations = filters.get('situation')
        if situations:
            situation_values = [str(s).strip().upper() for s in situations if s is not None]
            if situation_values:
                placeholders = ','.join(['%s'] * len(situation_values))
                query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
                params.extend(situation_values)

        lines = filters.get('line')
        if lines:
            line_values = [str(l).strip().upper() for l in lines if str(l).strip()]
            if line_values:
                placeholders = ','.join(['%s'] * len(line_values))
                query += f" AND {line_filter_expression} IN ({placeholders})"
                params.extend(line_values)

        transactions = filters.get('transaction')
        if transactions:
            transaction_values = [str(t).strip() for t in transactions if str(t).strip()]
            if transaction_values:
                placeholders = ','.join(['%s'] * len(transaction_values))
                query += f" AND COALESCE(op.opetransac::text, '') IN ({placeholders})"
                params.extend(transaction_values)

        query += " GROUP BY 1,2,3,4,5,6,7,8,9"
        query += " ORDER BY vendor_name, customer_name, city, line, sub_group, product_name"

        cur.execute(query, params)
        for (
            vendor_code,
            vendor_name,
            customer_code,
            customer_name,
            city,
            line,
            sub_group,
            product_name,
            product_code,
            total_value,
        ) in cur.fetchall():
            data.append({
                'vendor_code': vendor_code or '',
                'vendor_name': vendor_name or '',
                'customer_code': customer_code or '',
                'customer_name': customer_name or '',
                'city': city or 'Sem Cidade',
                'line': line or 'OUTROS',
                'sub_group': sub_group or 'Sem SubGrupo',
                'product_name': product_name or '',
                'product_code': product_code or '',
                'total_value': float(total_value or 0),
            })
        cur.close()
    except Error as e:
        print(f'Erro ao buscar dados da árvore de decomposição: {e}')
    finally:
        conn.close()

    return data


def get_dashboard_sales_summary():
    """Calcula o faturamento líquido do mês atual e a variação anual para o card do dashboard."""
    today = datetime.date.today()
    current_year = today.year
    current_month = today.month

    filters = {'month': [current_month]}

    current_year_totals = fetch_monthly_revenue(current_year, filters) or [0.0] * 12
    previous_year_totals = fetch_monthly_revenue(current_year - 1, filters) or [0.0] * 12

    current_value = current_year_totals[current_month - 1] if current_year_totals else 0.0
    previous_value = previous_year_totals[current_month - 1] if previous_year_totals else 0.0

    comparison_text = "Sem variação em relação ao mesmo mês do ano anterior."
    percent_change = None

    if previous_value not in (None, 0):
        percent_change = ((current_value - previous_value) / previous_value) * 100
        if isclose(percent_change, 0.0, abs_tol=1e-6):
            percent_change = 0.0
        formatted_percent = format_decimal_br(abs(percent_change), 1)
        if percent_change > 0:
            comparison_text = f"Aumento de {formatted_percent}% em relação ao mesmo mês do ano anterior."
        elif percent_change < 0:
            comparison_text = f"Queda de {formatted_percent}% em relação ao mesmo mês do ano anterior."
        else:
            comparison_text = "Sem variação em relação ao mesmo mês do ano anterior."
    else:
        if isclose(current_value, 0.0, abs_tol=1e-6):
            percent_change = 0.0
        else:
            comparison_text = "Sem base para comparação com o mesmo mês do ano anterior."

    return {
        'current_value': current_value,
        'previous_value': previous_value,
        'percent_change': percent_change,
        'comparison_text': comparison_text,
    }


def fetch_all_cfops():
    """Retorna todas as CFOPs cadastradas."""
    conn = get_erp_db_connection()
    cfops = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT operacao FROM opera ORDER BY operacao;")
            cfops = [str(row[0]).strip() for row in cur.fetchall() if row and row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar CFOPs: {e}')
        finally:
            conn.close()
    return cfops


def fetch_revenue_by_cfop(filters):
    """Retorna o faturamento agregado por CFOP."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_cfop'

            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, 'report_revenue_by_cfop_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT op.operacao,
                       SUM(tm.privltotal + tm.privlipi + tm.privlsubst) AS valor_bruto,
                       SUM(tm.privlipi) AS valor_ipi,
                       SUM(tm.privlsubst) AS valor_st,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY op.operacao, op.opetransac ORDER BY op.operacao"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            for cfop, bruto, ipi, st, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                data.append({
                    'cfop': cfop,
                    'valor_bruto': float(bruto or 0) * mult,
                    'valor_ipi': float(ipi or 0) * mult,
                    'valor_st': float(st or 0) * mult,
                    'valor_liquido': float(liquido or 0) * mult
                })
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por CFOP: {e}')
        finally:
            conn.close()

    return data


def fetch_revenue_by_line(filters):
    """Retorna o faturamento agregado por linha de produto."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_line'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT g.grunome,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY g.grunome, op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            line_totals = {}
            for group_name, liquido, transac in results:
                line = get_product_line(group_name)
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                line_totals[line] = line_totals.get(line, 0.0) + float(liquido or 0) * mult

            for line, total in line_totals.items():
                data.append({'line': line, 'valor_liquido': total})

            data.sort(key=lambda x: x['line'])
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por linha: {e}')
        finally:
            conn.close()

    return data


def fetch_average_price(filters):
    """Retorna o preço médio por linha e mês/ano."""
    conn = get_erp_db_connection()
    chart_labels = []
    chart_datasets = []
    treemap_data = []
    line_colors = {}

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_average_price'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT g.grunome,
                       TO_CHAR(tm.pridata, 'MM/YYYY') AS mes_ano,
                       SUM(tm.privltotal) AS valor,
                       SUM(tm.priquanti) AS quantidade,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY g.grunome, mes_ano, op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()

            line_month_totals = {}
            line_totals = {}
            all_months = set()
            for group_name, mes_ano, valor, quantidade, transac in results:
                line = get_product_line(group_name)
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                valor = float(valor or 0) * mult
                quantidade = float(quantidade or 0) * mult
                lm = line_month_totals.setdefault(line, {}).setdefault(mes_ano, {'valor': 0, 'quantidade': 0})
                lm['valor'] += valor
                lm['quantidade'] += quantidade
                lt = line_totals.setdefault(line, {'valor': 0, 'quantidade': 0})
                lt['valor'] += valor
                lt['quantidade'] += quantidade
                all_months.add(mes_ano)

            sorted_months = sorted(all_months, key=lambda x: datetime.datetime.strptime(x, '%m/%Y'))
            chart_labels = sorted_months

            color_palette = [
                '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
                '#FF9F40', '#C9CBCF', '#7FC97F', '#FDC086', '#386CB0'
            ]

            for idx, (line, months_data) in enumerate(line_month_totals.items()):
                data_points = []
                for m in sorted_months:
                    sums = months_data.get(m)
                    if sums and sums['quantidade'] != 0:
                        data_points.append(sums['valor'] / sums['quantidade'])
                    else:
                        data_points.append(0)
                color = color_palette[idx % len(color_palette)]
                chart_datasets.append({
                    'label': line,
                    'data': data_points,
                    'fill': True,
                    'borderColor': color,
                    'backgroundColor': f"{color}33"
                })
                line_colors[line] = color

            for line, totals in line_totals.items():
                avg = totals['valor'] / totals['quantidade'] if totals['quantidade'] else 0
                treemap_data.append({'x': line, 'v': avg})

            cur.close()
        except Error as e:
            print(f'Erro ao buscar preço médio: {e}')
        finally:
            conn.close()

    return chart_labels, chart_datasets, treemap_data, line_colors


def fetch_revenue_by_day(filters):
    """Retorna o faturamento agregado por dia."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_day'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT EXTRACT(DAY FROM tm.pridata) AS day,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            states = filters.get('state')
            if states:
                placeholders = ','.join(['%s'] * len(states))
                sql += f' AND c.estado IN ({placeholders})'
                params.extend(states)
            cities = filters.get('city')
            if cities:
                placeholders = ','.join(['%s'] * len(cities))
                sql += f" AND c.cidnome IN ({placeholders})"
                params.extend(cities)
            vendors = filters.get('vendor')
            if vendors:
                placeholders = ','.join(['%s'] * len(vendors))
                sql += f" AND d.vennome IN ({placeholders})"
                params.extend(vendors)

            lines = filters.get('line')
            if lines:
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) in lines:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY EXTRACT(DAY FROM tm.pridata), op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            day_totals = {}
            for day, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                day_key = int(day)
                day_totals[day_key] = day_totals.get(day_key, 0.0) + float(liquido or 0) * mult

            for day_key in sorted(day_totals.keys()):
                data.append({'day': day_key, 'valor_liquido': day_totals[day_key]})

            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por dia: {e}')
        finally:
            conn.close()

    return data


def fetch_revenue_by_state(filters):
    """Retorna o faturamento agregado por estado."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_state'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT c.estado AS uf,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE 1=1
            """
            params = []

            if filters.get('start_date'):
                sql += " AND tm.pridata >= %s"
                params.append(filters['start_date'])
            if filters.get('end_date'):
                sql += " AND tm.pridata <= %s"
                params.append(filters['end_date'])

            if not filters.get('start_date') and not filters.get('end_date'):
                sql += " AND EXTRACT(YEAR FROM tm.pridata) = %s"
                params.append(filters.get('year'))

                months = filters.get('month')
                if months:
                    month_tokens = months if isinstance(months, list) else [months]
                    valid_months = []
                    for m in month_tokens:
                        try:
                            valid_months.append(int(m))
                        except ValueError:
                            continue
                    if valid_months:
                        if len(valid_months) == 1:
                            sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                            params.append(valid_months[0])
                        else:
                            placeholders = ','.join(['%s'] * len(valid_months))
                            sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                            params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += ' GROUP BY c.estado, op.opetransac'


            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            state_totals = {}
            for uf, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                state_key = uf or 'N/D'
                state_totals[state_key] = state_totals.get(state_key, 0.0) + float(liquido or 0) * mult

            for state, total in state_totals.items():
                data.append({'state': state, 'valor_liquido': total})

            data.sort(key=lambda x: x['state'])
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por estado: {e}')
        finally:
            conn.close()

    return data

def fetch_revenue_by_vendor(filters):
    """Retorna o faturamento agregado por vendedor."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            user_id = session.get('user_id')
            report_id = 'report_revenue_by_vendor'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            try:
                cur = conn.cursor()
                sql = """
                        SELECT COALESCE(v.vennome, 'Sem Vendedor') AS vennome,
                               SUM(tm.privltotal) AS valor_liquido,
                               op.opetransac
                        FROM doctos d
                        LEFT JOIN empresa e ON d.notclifor = e.empresa
                        LEFT JOIN cidade c ON d.noscidade = c.cidade
                        LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                        LEFT JOIN ntvped1 np ON np.ntvnota = d.controle
                        LEFT JOIN comnf cf ON d.notdocto = cf.comncontr::text
                        LEFT JOIN vendedor v ON cf.comnvende = v.vendedor
                        LEFT JOIN produto p ON tm.priproduto = p.produto
                        LEFT JOIN grupo g ON p.grupo = g.grupo
                        LEFT JOIN opera op ON d.operacao = op.operacao
                        WHERE EXTRACT(YEAR FROM tm.pridata) = %s
                """
                params = [filters.get('year')]

                months = filters.get('month')
                if months:
                    month_tokens = months if isinstance(months, list) else [months]
                    valid_months = []
                    for m in month_tokens:
                        try:
                            valid_months.append(int(m))
                        except ValueError:
                            continue
                    if valid_months:
                        if len(valid_months) == 1:
                            sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                            params.append(valid_months[0])    
                        else:
                            placeholders = ','.join(['%s'] * len(valid_months))
                            sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                            params.extend(valid_months)

                if filters.get('state'):
                    sql += ' AND c.estado = %s'
                    params.append(filters['state'])
                if filters.get('city'):
                    sql += " AND c.cidnome = %s"
                    params.append(filters['city'])
                if filters.get('vendor'):
                    sql += " AND d.vennome = %s"
                    params.append(filters['vendor'])

                if filters.get('line'):
                    matching_group_codes = []
                    temp_conn = get_erp_db_connection()
                    if temp_conn:
                        try:
                            temp_cur = temp_conn.cursor()
                            temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                            groups_data = temp_cur.fetchall()
                            temp_cur.close()
                            for code, name in groups_data:
                                if get_product_line(name) == filters['line']:
                                    matching_group_codes.append(code)
                        except Error as e:
                            print(f'Erro ao buscar grupos para filtro de linha: {e}')
                        finally:
                            temp_conn.close()
                    if matching_group_codes:
                        placeholders = ','.join(['%s'] * len(matching_group_codes))
                        sql += f" AND g.grupo IN ({placeholders})"
                        params.extend(matching_group_codes)
                    else:
                        sql += " AND FALSE"

                if selected_transactions:
                    placeholders = ','.join(['%s'] * len(selected_transactions))
                    sql += f" AND op.opetransac IN ({placeholders})"
                    params.extend(selected_transactions)
                if selected_cfops:
                    placeholders = ','.join(['%s'] * len(selected_cfops))
                    sql += f" AND op.operacao IN ({placeholders})"
                    params.extend(selected_cfops)
                sql += " GROUP BY COALESCE(v.vennome, 'Sem Vendedor'), op.opetransac"

                cur.execute(sql, tuple(params))
                results = cur.fetchall()
                vendor_totals = {}
                for name, liquido, transac in results:
                    vendor = name
                    sign = transaction_signs.get(str(transac), '+')
                    mult = -1 if sign == '-' else 1
                    vendor_totals[vendor] = vendor_totals.get(vendor, 0.0) + float(liquido or 0) * mult

                for vendor, total in vendor_totals.items():
                    data.append({'vendor': vendor, 'valor_liquido': total})

                data.sort(key=lambda x: x['vendor'])
                cur.close()
            except UndefinedColumn:
                conn.rollback()
                cur.close()
                data.clear()
        except Error as e:
            print(f'Erro ao buscar faturamento por vendedor: {e}')
        finally:
            conn.close()

    return data

def parse_regcar_description(rgcdes_string):
    """
    Parses the rgcdes string to extract freight percentages and M³ value.
    Replicates the Power Query M script logic.
    Example: "P0.05;M0.03;G0.02;#0.01;V0.04;S0.06;$1.2"
    """
    data = {
        'P': 0.0, 'M': 0.0, 'G': 0.0, '#': 0.0, 'V': 0.0, 'S': 0.0, 'M3': 0.0
    }
    if not rgcdes_string:
        return data

    # Substitui vírgulas por pontos para garantir a conversão correta para float
    rgcdes_string = rgcdes_string.replace(',', '.')

    # Use regex to find patterns like [LETTER][NUMBER]; or $[NUMBER]
    patterns = {
        'P': r"P([\d.]+)(?:;|$)",
        'M': r"M([\d.]+)(?:;|$)",
        'G': r"G([\d.]+)(?:;|$)",
        '#': r"#([\d.]+)(?:;|$)",
        'V': r"V([\d.]+)(?:;|$)",
        'S': r"S([\d.]+)(?:;|$)",
        'M3': r"\$([\d.]+)"
    }

    for key, pattern in patterns.items():
        match = re.search(pattern, rgcdes_string)
        if match:
            try:
                value = float(match.group(1))
                data[key] = value
            except ValueError:
                pass # If conversion to float fails, keep default 0.0
    return data

def calculate_freight_percentage(product_line, product_ref, regcar_parsed_data):
    """
    Calculates the freight percentage based on product line, product reference,
    and parsed regcar data, replicating the DAX formula.
    """
    if not regcar_parsed_data:
        return 0.0

    product_ref_upper = product_ref.upper() if product_ref else ""

    if product_line == "MADRESILVA":
        return regcar_parsed_data.get('M', 0.0)
    elif product_line == "PETRA":
        return regcar_parsed_data.get('P', 0.0)
    elif product_line == "SOLARE":
        return regcar_parsed_data.get('S', 0.0)
    elif product_line == "GLASSMADRE":
        return regcar_parsed_data.get('V', 0.0)
    elif product_line == "GARLAND":
        if product_ref_upper in ["SF", "NM", "RC", "CH", "SC"]:
            return regcar_parsed_data.get('G', 0.0)
        elif product_ref_upper in ["PF", "PT", "AL", "MA", "MC"]:
            return regcar_parsed_data.get('#', 0.0)
    return 0.0 # Default if no condition matches

def calculate_invoice_freight(controle):
    """Calcula o percentual e o valor de frete de uma nota fiscal com base
    nos itens da nota."""
    conn = get_erp_db_connection()
    total_produtos = 0.0
    total_frete = 0.0
    freight_percentage = 0.0

    if conn:
        try:
            cur = conn.cursor()

            # Recupera o rgcdes da nota para calcular o frete
            cur.execute(
                """
                SELECT COALESCE(rc.rgcdes, '')
                FROM doctos d
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN regcar rc ON c.rgccicod = rc.rgccod
                WHERE d.controle = %s
                """,
                (controle,)
            )
            rgcdes_row = cur.fetchone()
            rgcdes = rgcdes_row[0] if rgcdes_row else ''
            regcar_data = parse_regcar_description(rgcdes)

            # Busca os itens da nota
            cur.execute(
                """
                SELECT tm.privltotal, p.pronome, g.grunome
                FROM toqmovi tm
                JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                WHERE tm.itecontrol = %s
                """,
                (controle,),
            )
            items = cur.fetchall()

            for privltotal, pronome, grunome in items:
                item_valor = float(privltotal or 0.0)
                product_line = get_product_line(grunome)
                product_ref = pronome[:2] if pronome else ''
                perc_item = calculate_freight_percentage(
                    product_line, product_ref, regcar_data
                )
                total_frete += perc_item * item_valor
                total_produtos += item_valor

            if total_produtos:
                freight_percentage = (total_frete / total_produtos) * 100
        except Error as e:
            print(f"Erro ao calcular frete da nota {controle}: {e}")
        finally:
            conn.close()

    return freight_percentage, total_frete

@app.route('/invoices_mirror')
@login_required
def invoices_mirror():
    """
    Rota que exibe o espelho das notas fiscais faturadas com filtros.
    """
    conn = get_erp_db_connection() # Conecta ao DB do ERP
    invoices_data = []  # Para armazenar os dados processados
    totals_summary = {
        'valor_produtos': 0.0,
        'valor_ipi': 0.0,
        'valor_st': 0.0,
        'valor_total': 0.0,
        'valor_frete': 0.0
    }

    # Get current date for default filter values
    today = datetime.date.today().isoformat() # Format as YYYY-MM-DD for HTML input type="date"

    # Initialize filters dictionary
    filters = {
        'start_date': request.args.get('start_date'),
        'end_date': request.args.get('end_date'),
        'client_name': request.args.get('client_name'),
        'document_number': request.args.get('document_number'),
        'lotecar_code': request.args.get('lotecar_code'),
        'product_line': request.args.get('product_line')
    }

    # If no date filters are provided, set them to today's date
    if not filters['start_date'] and not filters['end_date']:
        filters['start_date'] = today
        filters['end_date'] = today

    # Get distinct product lines for the filter combobox
    product_lines = get_distinct_product_lines()

    # Obter transações selecionadas pelo usuário
    user_id = session.get('user_id')
    transaction_signs = parse_transaction_signs(
        get_user_parameters(user_id, 'invoices_mirror_invoice_transaction_signs')
    )
    selected_transactions = list(transaction_signs.keys())
    if not selected_transactions:
        selected_transactions_str = get_user_parameters(
            user_id, 'invoices_mirror_selected_invoice_transactions'
        )
        if selected_transactions_str:
            selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
            transaction_signs = {t: '+' for t in selected_transactions}
    if selected_transactions:
        print(f"DEBUG: Transações selecionadas para o usuário {user_id}: {selected_transactions}")

    selected_cfops_str = get_user_parameters(
        user_id, 'invoices_mirror_selected_report_cfops'
    )
    selected_cfops = []
    if selected_cfops_str:
        selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

    if conn:
        try:
            cur = conn.cursor()
            # Base SQL query
            sql_query = """
                SELECT
                    d.controle,
                    d.notdocto,
                    d.notdata,
                    d.notvltotal,
                    e.empnome AS client_name,
                    d.notvlipi,
                    COALESCE(SUM(tm.privltotal), 0) AS total_privltotal,
                    COALESCE(SUM(tm.privlsubst), 0) AS total_privlsubst,
                    COALESCE(MAX(rc.rgcdes), '') AS rgcdes_agg,
                    COALESCE(MAX(p.pronome), '') AS pronome_agg,
                    COALESCE(MAX(g.grunome), '') AS grunome_agg,
                    op.opetransac
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
                LEFT JOIN
                    lotecar lc ON d.vollcacod = lc.lcacod
                LEFT JOIN
                    toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN
                    cidade c ON d.noscidade = c.cidade
                LEFT JOIN
                    regcar rc ON c.rgccicod = rc.rgccod
                LEFT JOIN
                    produto p ON tm.priproduto = p.produto
                LEFT JOIN
                    grupo g ON p.grupo = g.grupo
                LEFT JOIN
                    opera op ON d.operacao = op.operacao
            """
            query_params = []
            where_clauses = []

            if filters['start_date']:
                where_clauses.append("tm.pridata >= %s")
                query_params.append(filters['start_date'])
            if filters['end_date']:
                where_clauses.append("tm.pridata <= %s")
                query_params.append(filters['end_date'])
            if filters['client_name']:
                where_clauses.append("e.empnome ILIKE %s")
                query_params.append(f"%{filters['client_name']}%")
            if filters['document_number']:
                where_clauses.append("d.notdocto = %s")
                query_params.append(filters['document_number'])
            if filters['lotecar_code']:
                where_clauses.append("lc.lcacod = %s")
                query_params.append(filters['lotecar_code'])
            
            # Filtro por linha de produto
            if filters['product_line']:
                matching_group_codes = []
                temp_conn_for_groups = get_erp_db_connection()
                if temp_conn_for_groups:
                    try:
                        temp_cur_for_groups = temp_conn_for_groups.cursor()
                        temp_cur_for_groups.execute("SELECT grupo, grunome FROM grupo;")
                        all_groups_data = temp_cur_for_groups.fetchall()
                        temp_cur_for_groups.close()
                        for group_code, group_name in all_groups_data:
                            if get_product_line(group_name) == filters['product_line']:
                                matching_group_codes.append(group_code)
                    except Error as e:
                        print(f"Erro ao buscar grupos para filtro de linha de produto: {e}")
                    finally:
                        if temp_conn_for_groups:
                            temp_conn_for_groups.close()

                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    where_clauses.append(f"g.grupo IN ({placeholders})")
                    query_params.extend(matching_group_codes)
                else:
                    where_clauses.append("FALSE")
            
            # Novo filtro por transações selecionadas
            if selected_transactions:
                # Mantém as transações como strings para corresponder ao tipo da coluna
                valid_transactions = [t for t in selected_transactions if t]
                if valid_transactions:
                    placeholders = ','.join(['%s'] * len(valid_transactions))
                    where_clauses.append(f"op.opetransac IN ({placeholders})")
                    query_params.extend(valid_transactions)
                else:
                    where_clauses.append("FALSE")

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                where_clauses.append(f"op.operacao IN ({placeholders})")
                query_params.extend(selected_cfops)

            if where_clauses:
                sql_query += " WHERE " + " AND ".join(where_clauses)

            sql_query += """
                GROUP BY
                    d.controle, d.notdocto, d.notdata, d.notvltotal, e.empnome,
                    d.notvlipi, op.opetransac
            """
            sql_query += " ORDER BY d.notdata DESC, d.controle DESC;"

            cur.execute(sql_query, tuple(query_params))
            raw_invoices = cur.fetchall()
            cur.close()

            for row in raw_invoices:
                invoice = {
                    'controle': row[0],
                    'notdocto': row[1],
                    'notdata': row[2],
                    'notvltotal': row[3],
                    'client_name': row[4],
                    'notvlipi': row[5],
                    'total_privltotal': row[6], # Valor Produtos
                    'total_privlsubst': row[7], # Valor ST
                    'rgcdes': row[8], # rgcdes_agg
                    'pronome': row[9], # pronome_agg
                    'grunome': row[10], # grunome_agg
                    'operacao': row[11] # Código da transação
                }
                print(
                    f"Processing invoice {invoice['controle']}: rgcdes='{invoice['rgcdes']}', pronome='{invoice['pronome']}', grunome='{invoice['grunome']}'"
                )  # DEBUG

                freight_percentage, valor_frete = calculate_invoice_freight(invoice['controle'])

                invoice['freight_percentage'] = freight_percentage
                invoice['valor_frete'] = valor_frete

                invoices_data.append(invoice)

                # Acumula totais para o rodapé
                sign = transaction_signs.get(str(invoice['operacao']), '+')
                multiplier = -1 if sign == '-' else 1
                totals_summary['valor_produtos'] += multiplier * float(invoice['total_privltotal'] or 0)
                totals_summary['valor_ipi'] += multiplier * float(invoice['notvlipi'] or 0)
                totals_summary['valor_st'] += multiplier * float(invoice['total_privlsubst'] or 0)
                totals_summary['valor_total'] += multiplier * float(invoice['notvltotal'] or 0)
                totals_summary['valor_frete'] += multiplier * float(invoice['valor_frete'] or 0)

        except Error as e:
            print(f"Erro ao executar a consulta: {e}")
            flash(f"Erro ao carregar notas fiscais: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template(
        'invoices_mirror.html',
        invoices=invoices_data,
        filters=filters,
        product_lines=product_lines,
        totals=totals_summary,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/api/get_lotecar_description/<string:lotecar_code>')
@login_required
def get_lotecar_description(lotecar_code):
    """
    Rota de API para buscar a descrição de um lote de carga pelo código.
    """
    conn = get_erp_db_connection()
    description = ""
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT lcades FROM lotecar WHERE lcacod = %s", (lotecar_code,))
            result = cur.fetchone()
            if result:
                description = result[0]
            cur.close()
        except Error as e:
            print(f"Erro ao buscar descrição do lote de carga: {e}")
        finally:
            if conn:
                conn.close()
    return jsonify({'description': description})

@app.route('/api/get_invoice_details/<int:controle>')
@login_required
def get_invoice_details(controle):
    """
    Rota de API para buscar detalhes de uma nota fiscal específica (cabeçalho e itens).
    """
    print(f"DEBUG: get_invoice_details called for controle: {controle}") # DEBUG
    conn = get_erp_db_connection()
    invoice_header = {}
    invoice_items = []
    
    if conn:
        try:
            cur = conn.cursor()

            # Buscar dados do cabeçalho da nota fiscal
            cur.execute("""
                SELECT
                    d.notdocto,
                    d.notclifor,
                    e.empnome,
                    op.opetransac,
                    d.notdata,
                    d.notvltotal,
                    COALESCE(rc.rgcdes, '') AS rgcdes
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
                LEFT JOIN
                    opera op ON d.operacao = op.operacao
                LEFT JOIN
                    cidade c ON d.noscidade = c.cidade
                LEFT JOIN
                    regcar rc ON c.rgccicod = rc.rgccod
                WHERE
                    d.controle = %s
            """, (controle,))
            header_data = cur.fetchone()
            print(f"DEBUG: Header data for controle {controle}: {header_data}") # DEBUG
            if header_data:
                invoice_header = {
                    'notdocto': header_data[0],
                    'notclifor': header_data[1],
                    'empnome': header_data[2],
                    'operacao': header_data[3],  # Código da transação
                    'notdata': header_data[4].strftime('%d/%m/%Y') if header_data[4] else 'N/A',
                    'notvltotal': float(header_data[5]) if header_data[5] is not None else 0.0,
                    'rgcdes': header_data[6]
                }

            # Buscar itens de produto da nota fiscal
            cur.execute("""
                SELECT
                    tm.prisequen,
                    tm.priproduto,
                    p.pronome,
                    p.unimedida,
                    tm.priquanti,
                    tm.pritmpuni,
                    tm.privltotal,
                    tm.prialqipi,
                    tm.privlipi,
                    tm.privlsubst,
                    COALESCE(g.grunome, '') AS grunome
                FROM
                    toqmovi tm
                JOIN
                    produto p ON tm.priproduto = p.produto
                LEFT JOIN
                    grupo g ON p.grupo = g.grupo
                WHERE
                    tm.itecontrol = %s
                ORDER BY
                    tm.prisequen
            """, (controle,))
            items_data = cur.fetchall()
            print(f"DEBUG: Items data for controle {controle}: {items_data}") # DEBUG

            regcar_data = parse_regcar_description(invoice_header.get('rgcdes', ''))

            for item in items_data:
                item_privltotal = item[6] if item[6] is not None else 0
                item_privlipi = item[8] if item[8] is not None else 0
                item_privlsubst = item[9] if item[9] is not None else 0
                
                valor_total_item = item_privltotal + item_privlipi + item_privlsubst

                product_line = get_product_line(item[10])
                product_ref = item[2][:2] if item[2] else ""
                freight_pct = calculate_freight_percentage(product_line, product_ref, regcar_data)

                freight_percentage_display = freight_pct * 100
                valor_frete_item = (freight_percentage_display / 100) * float(item_privltotal)

                invoice_items.append({
                    'prisequen': item[0],
                    'priproduto': item[1],
                    'pronome': item[2],
                    'unimedida': item[3],
                    'priquanti': float(item[4]) if item[4] is not None else 0.0,
                    'pritmpuni': float(item[5]) if item[5] is not None else 0.0,
                    'privltotal': float(item_privltotal),
                    'prialqipi': float(item[7]) if item[7] is not None else 0.0,
                    'privlipi': float(item_privlipi),
                    'privlsubst': float(item_privlsubst),
                    'valor_total_item': float(valor_total_item),
                    'freight_percentage': freight_percentage_display,
                    'valor_frete': valor_frete_item
                })
            cur.close()

        except Error as e:
            print(f"ERRO ao buscar detalhes da nota fiscal no backend: {e}") # DEBUG
            return jsonify({'error': str(e)}), 500
        finally:
            if conn:
                conn.close()
    
    print(f"DEBUG: Returning details for controle {controle}: Header={invoice_header}, Items count={len(invoice_items)}") # DEBUG
    return jsonify({
        'header': invoice_header,
        'items': invoice_items
    })

@app.route('/api/get_group_product_line/<string:group_name>')
@login_required
def get_group_product_line_api(group_name):
    """
    Rota de API para buscar a linha de produto de um grupo.
    """
    line = get_product_line(group_name)
    return jsonify({'product_line': line})


# --- Rotas de Placeholder para o Menu (Cadastros) ---
@app.route('/companies_list')
@login_required
def companies_list():
    return render_template('placeholder.html', page_title="Lista de Empresas", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/products_list')
@login_required
def products_list():
    return render_template('placeholder.html', page_title="Lista de Produtos", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/vendors_list')
@login_required
def vendors_list():
    return render_template('placeholder.html', page_title="Lista de Vendedores", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/cities_list')
@login_required
def cities_list():
    return render_template('placeholder.html', page_title="Lista de Cidades", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/groups_list')
@login_required
def groups_list():
    """
    Rota para listar os grupos de produto e suas respectivas linhas.
    """
    conn = get_erp_db_connection()
    groups = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT grupo, grunome FROM grupo ORDER BY grunome;")
            raw_groups = cur.fetchall()
            cur.close()

            for group_data in raw_groups:
                group_code = group_data[0]
                group_name = group_data[1]
                product_line = get_product_line(group_name) # Calcula a linha de produto
                groups.append({'grupo': group_code, 'grunome': group_name, 'linha': product_line})

        except Error as e:
            print(f"Erro ao carregar lista de grupos: {e}")
            flash(f"Erro ao carregar grupos: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('groups_list.html', groups=groups, page_title="Lista de Grupos de Produto", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))


@app.route('/conditions_list')
@login_required
def conditions_list():
    return render_template('placeholder.html', page_title="Lista de Condições de Pagamento", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/operations_list')
@login_required
def operations_list():
    return render_template('placeholder.html', page_title="Lista de Operações", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/transporters_list')
@login_required
def transporters_list():
    return render_template('placeholder.html', page_title="Lista de Transportadoras", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

def calculate_order_kpi(reservado_raw, separado_raw, carregado_raw):
    """
    Reproduz a regra DAX que classifica o status do pedido com base em Reservado, Separado e Carregado.
    Retorna:
        None  -> reservado ou separado em branco (cor vermelha)
        0     -> separado igual a zero (cor vermelha)
        1     -> separado entre 0 e reservado (cor amarela)
        2     -> separado igual a reservado e carregado menor que reservado (cor verde)
        3     -> carregado igual a reservado (cor azul)
    """
    if reservado_raw is None or separado_raw is None:
        return None

    try:
        reservado = float(reservado_raw)
    except (TypeError, ValueError):
        reservado = 0.0

    try:
        separado = float(separado_raw)
    except (TypeError, ValueError):
        separado = 0.0

    try:
        carregado = float(carregado_raw) if carregado_raw is not None else 0.0
    except (TypeError, ValueError):
        carregado = 0.0

    rel_tol = 1e-6
    abs_tol = 1e-6

    def is_less_than(a, b):
        return a < b and not isclose(a, b, rel_tol=rel_tol, abs_tol=abs_tol)

    if isclose(separado, 0.0, rel_tol=rel_tol, abs_tol=abs_tol):
        return 0
    if separado > 0 and is_less_than(separado, reservado):
        return 1
    if isclose(separado, reservado, rel_tol=rel_tol, abs_tol=abs_tol) and is_less_than(carregado, reservado):
        return 2
    if isclose(carregado, reservado, rel_tol=rel_tol, abs_tol=abs_tol):
        return 3
    return None

# --- Rotas de Placeholder para o Menu (Vendas) ---
def fetch_orders(filters):
    """Busca os pedidos com agregações e metadados necessários para planejamento de rota."""
    orders = []
    error_message = None
    conn = get_erp_db_connection()

    if not conn:
        return orders, "Não foi possível conectar ao banco de dados do ERP."

    has_lcapecod_column = False
    column_check_cursor = None
    items_cur = None
    pedprodu_columns = None
    cidade_columns = None

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'pedido'
                  AND column_name = 'lcapecod'
            )
            """
        )
        result = column_check_cursor.fetchone()
        if result:
            has_lcapecod_column = result[0]
    except Error as e:
        print(f"Erro ao verificar a coluna 'lcapecod' na tabela 'pedido': {e}")
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    try:
        cidade_columns = get_table_columns(conn, 'cidade')
    except Error as e:
        print(f"Erro ao analisar colunas da tabela 'cidade': {e}")
        cidade_columns = set()

    latitude_column = None
    longitude_column = None
    if cidade_columns:
        for candidate in ('cidlatitude', 'latitude', 'cidlat', 'latitude_gps'):
            if candidate in cidade_columns:
                latitude_column = candidate
                break
        for candidate in ('cidlongitude', 'longitude', 'cidlong', 'longitude_gps'):
            if candidate in cidade_columns:
                longitude_column = candidate
                break

    latitude_select = f"COALESCE(c.{latitude_column}, 0) AS cidade_latitude," if latitude_column else "NULL AS cidade_latitude,"
    longitude_select = f"COALESCE(c.{longitude_column}, 0) AS cidade_longitude," if longitude_column else "NULL AS cidade_longitude,"

    cidade_select = (
        "CASE "
        "WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome "
        "WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text "
        "ELSE '' "
        "END"
    )
    estado_select = (
        "CASE "
        "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
        "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
        "ELSE '' "
        "END"
    )

    try:
        cur = conn.cursor()
        query = f"""
            WITH prod_quant AS (
                SELECT pedido, SUM(COALESCE(pprquanti, 0)) AS total_quantidade
                FROM pedprodu
                GROUP BY pedido
            ),
            proj_totals AS (
                SELECT prjmpedid AS pedido,
                       SUM(CASE WHEN prjmovtip = 'R' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS reservado,
                       SUM(CASE WHEN prjmovtip = 'P' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS separado,
                       SUM(CASE WHEN prjmovtip = 'C' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS carregado
                FROM projmovi
                GROUP BY prjmpedid
            ),
            linha_info AS (
                SELECT
                    sub.pedido,
                    (ARRAY_AGG(sub.linha_value ORDER BY sub.priority))[1] AS linha
                FROM (
                    SELECT DISTINCT
                        base_data.pedido,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 'MADRESILVA'
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 'PETRA'
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 'GARLAND'
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 'GLASSMADRE'
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 'CAVILHAS'
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 'SOLARE'
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 'ESPUMA'
                            ELSE 'OUTROS'
                        END AS linha_value,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 1
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 2
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 3
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 4
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 5
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 6
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 7
                            ELSE 999
                        END AS priority
                    FROM (
                        SELECT
                            pp.pedido,
                            UPPER(COALESCE(g.grunome, '')) AS group_name_upper
                        FROM pedprodu pp
                        LEFT JOIN produto prod ON prod.produto = pp.pprproduto
                        LEFT JOIN grupo g ON g.grupo = prod.grupo
                        WHERE pp.pedido IS NOT NULL
                    ) base_data
                ) sub
                GROUP BY sub.pedido
            ),
            production_lots AS (
                SELECT
                    CAST(lots.pedido AS TEXT) AS pedido,
                    STRING_AGG(lots.lot_display, '; ' ORDER BY lots.lot_display) AS production_lots_display
                FROM (
                    SELECT DISTINCT
                        ao.acaopedi AS pedido,
                        CASE
                            WHEN COALESCE(lp.lotcod::text, '') <> '' THEN
                                lp.lotcod::text ||
                                CASE
                                    WHEN COALESCE(lp.lotdes, '') <> '' THEN ' - ' || lp.lotdes
                                    ELSE ''
                                END
                            ELSE ''
                        END AS lot_display
                    FROM acaorde2 ao
                    JOIN ordem o ON o.ordem = ao.acaoorde
                    LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
                    WHERE ao.acaopedi IS NOT NULL
                ) lots
                WHERE lots.lot_display <> ''
                GROUP BY lots.pedido
            )
            SELECT
                p.pedido,
                p.lcaseque,
                p.pedcliente,
                COALESCE(e.empnome, '') AS empnome,
                {cidade_select} AS cidade,
                {estado_select} AS estado,
                {latitude_select}
                {longitude_select}
                CASE
                    WHEN COALESCE(c.cidnome, '') <> '' AND COALESCE(c.estado, '') <> '' THEN c.cidnome || '/' || c.estado
                    WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome
                    WHEN COALESCE(c.estado, '') <> '' THEN c.estado
                    WHEN COALESCE(p.pedentcid::text, '') <> '' AND COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentcid::text || '/' || p.pedentuf::text
                    WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text
                    WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text
                    ELSE ''
                END AS cidade_uf,
                COALESCE(prod.total_quantidade, 0) AS quantidade_total,
                COALESCE(proj.reservado, 0) AS reservado,
                COALESCE(proj.separado, 0) AS separado,
                COALESCE(proj.carregado, 0) AS carregado,
                COALESCE(linha.linha, 'OUTROS') AS linha,
                COALESCE(p.pedaprova, '') AS approval_status_code,
                COALESCE(p.pedsitua, '') AS situation_code,
                COALESCE(pl.production_lots_display, '') AS production_lots_display
            FROM pedido p
            LEFT JOIN empresa e ON p.pedcliente = e.empresa
            LEFT JOIN cidade c ON p.pedentcid = c.cidade
            LEFT JOIN prod_quant prod ON p.pedido = prod.pedido
            LEFT JOIN proj_totals proj ON p.pedido = proj.pedido
            LEFT JOIN linha_info linha ON p.pedido = linha.pedido
            LEFT JOIN production_lots pl ON pl.pedido = CAST(p.pedido AS TEXT)
        """
        if has_lcapecod_column:
            query += "            LEFT JOIN lotecar lc ON p.lcapecod = lc.lcacod\n"
        query += "            WHERE 1 = 1\n"

        params = []

        load_lots_filter = filters.get('load_lots') or []
        if load_lots_filter:
            if has_lcapecod_column:
                placeholders = ', '.join(['%s'] * len(load_lots_filter))
                query += f" AND CAST(p.lcapecod AS TEXT) IN ({placeholders})"
                params.extend(load_lots_filter)
            else:
                print("Coluna 'lcapecod' ausente na tabela 'pedido'; filtro 'Lote de Carga' foi ignorado.")
        elif filters.get('load_lot'):
            if has_lcapecod_column:
                query += " AND (CAST(p.lcapecod AS TEXT) ILIKE %s OR COALESCE(lc.lcades, '') ILIKE %s)"
                params.append(f"%{filters['load_lot']}%")
                params.append(f"%{filters['load_lot']}%")
            else:
                print("Coluna 'lcapecod' ausente na tabela 'pedido'; filtro 'Lote de Carga' foi ignorado.")

        production_lots_filter = filters.get('production_lots') or []
        if production_lots_filter:
            placeholders = ', '.join(['%s'] * len(production_lots_filter))
            query += f"""
                AND EXISTS (
                    SELECT 1
                    FROM acaorde2 ao
                    JOIN ordem o ON o.ordem = ao.acaoorde
                    WHERE ao.acaopedi = p.pedido
                      AND CAST(o.lotcod AS TEXT) IN ({placeholders})
                )
            """
            params.extend(production_lots_filter)

        lines_filter = filters.get('lines') or []
        if lines_filter:
            placeholders = ', '.join(['%s'] * len(lines_filter))
            query += f" AND COALESCE(linha.linha, '') IN ({placeholders})"
            params.extend(lines_filter)
        elif filters.get('line'):
            query += " AND COALESCE(linha.linha, '') ILIKE %s"
            params.append(f"%{filters['line']}%")

        def parse_decimal_filter(raw_value):
            if raw_value is None:
                return None
            value = str(raw_value).strip()
            if not value:
                return None
            normalized = value.replace(' ', '')
            if ',' in normalized and '.' in normalized:
                normalized = normalized.replace('.', '').replace(',', '.')
            elif ',' in normalized:
                normalized = normalized.replace(',', '.')
            try:
                return Decimal(normalized)
            except InvalidOperation:
                return None

        pedido_filter = (filters.get('filter_pedido') or '').strip()
        if pedido_filter:
            params.append(f"%{pedido_filter}%")
            query += " AND CAST(p.pedido AS TEXT) ILIKE %s"

        seq_lote_filter = (filters.get('filter_seq_lote') or '').strip()
        if seq_lote_filter:
            params.append(f"%{seq_lote_filter}%")
            query += " AND COALESCE(CAST(p.lcaseque AS TEXT), '') ILIKE %s"

        cliente_codigo_filter = (filters.get('filter_cliente_codigo') or '').strip()
        if cliente_codigo_filter:
            params.append(f"%{cliente_codigo_filter}%")
            query += " AND COALESCE(CAST(p.pedcliente AS TEXT), '') ILIKE %s"

        cliente_nome_filter = (filters.get('filter_cliente_nome') or '').strip()
        if cliente_nome_filter:
            params.append(f"%{cliente_nome_filter}%")
            query += " AND COALESCE(e.empnome, '') ILIKE %s"

        cidade_filter = (filters.get('filter_cidade_uf') or '').strip()
        if cidade_filter:
            like_value = f"%{cidade_filter}%"
            query += """
                AND (
                    COALESCE(c.cidnome, '') ILIKE %s
                    OR COALESCE(c.estado, '') ILIKE %s
                    OR (COALESCE(c.cidnome, '') || '/' || COALESCE(c.estado, '')) ILIKE %s
                    OR COALESCE(CAST(p.pedentcid AS TEXT), '') ILIKE %s
                    OR COALESCE(CAST(p.pedentuf AS TEXT), '') ILIKE %s
                    OR (COALESCE(CAST(p.pedentcid AS TEXT), '') || '/' || COALESCE(CAST(p.pedentuf AS TEXT), '')) ILIKE %s
                )
            """
            params.extend([like_value] * 6)

        quantidade_filter = parse_decimal_filter(filters.get('filter_quantidade_total'))
        if quantidade_filter is not None:
            query += " AND COALESCE(prod.total_quantidade, 0) = %s"
            params.append(quantidade_filter)

        reservado_filter = parse_decimal_filter(filters.get('filter_reservado'))
        if reservado_filter is not None:
            query += " AND COALESCE(proj.reservado, 0) = %s"
            params.append(reservado_filter)

        separado_filter = parse_decimal_filter(filters.get('filter_separado'))
        if separado_filter is not None:
            query += " AND COALESCE(proj.separado, 0) = %s"
            params.append(separado_filter)

        carregado_filter = parse_decimal_filter(filters.get('filter_carregado'))
        if carregado_filter is not None:
            query += " AND COALESCE(proj.carregado, 0) = %s"
            params.append(carregado_filter)

        linha_filter = (filters.get('filter_linha') or '').strip()
        if linha_filter:
            params.append(f"%{linha_filter}%")
            query += " AND COALESCE(linha.linha, 'OUTROS') ILIKE %s"

        approval_status_filter = filters.get('approval_statuses') or []
        if approval_status_filter:
            placeholders = ', '.join(['%s'] * len(approval_status_filter))
            query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
            params.extend(approval_status_filter)

        situation_filter = filters.get('situations') or []
        if situation_filter:
            placeholders = ', '.join(['%s'] * len(situation_filter))
            query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
            params.extend(situation_filter)

        if filters.get('start_date'):
            try:
                start_date = datetime.datetime.strptime(filters['start_date'], '%Y-%m-%d').date()
                query += " AND p.peddata >= %s"
                params.append(start_date)
            except ValueError:
                pass

        if filters.get('end_date'):
            try:
                end_date = datetime.datetime.strptime(filters['end_date'], '%Y-%m-%d').date()
                query += " AND p.peddata <= %s"
                params.append(end_date)
            except ValueError:
                pass

        sort_by = (filters.get('sort_by') or 'pedido').strip()
        sort_order = (filters.get('sort_order') or 'desc').strip().lower()

        sort_column_map = {
            'pedido': 'p.pedido',
            'lcaseque': 'p.lcaseque',
            'cliente_codigo': 'p.pedcliente',
            'cliente_nome': 'empnome',
            'cidade_uf': 'cidade_uf',
            'quantidade_total': 'quantidade_total',
            'reservado': 'reservado',
            'separado': 'separado',
            'carregado': 'carregado',
            'linha': 'linha',
        }

        sort_column = sort_column_map.get(sort_by, 'p.pedido')
        sort_direction = 'ASC' if sort_order == 'asc' else 'DESC'

        query += f" ORDER BY {sort_column} {sort_direction}, p.pedido DESC"

        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            (
                pedido,
                lcaseque,
                cliente_codigo,
                cliente_nome,
                cidade_nome,
                estado_sigla,
                latitude_raw,
                longitude_raw,
                cidade_uf,
                quantidade_total_raw,
                reservado_raw,
                separado_raw,
                carregado_raw,
                linha,
                approval_code,
                situation_code,
                production_lots_display,
            ) = row

            kpi_status = calculate_order_kpi(reservado_raw, separado_raw, carregado_raw)

            try:
                quantidade_total = float(quantidade_total_raw) if quantidade_total_raw is not None else 0.0
            except (TypeError, ValueError):
                quantidade_total = 0.0

            try:
                reservado = float(reservado_raw) if reservado_raw is not None else 0.0
            except (TypeError, ValueError):
                reservado = 0.0

            try:
                separado = float(separado_raw) if separado_raw is not None else 0.0
            except (TypeError, ValueError):
                separado = 0.0

            try:
                carregado = float(carregado_raw) if carregado_raw is not None else 0.0
            except (TypeError, ValueError):
                carregado = 0.0

            def parse_coord(raw_value):
                if raw_value in (None, ''):
                    return None
                try:
                    return float(raw_value)
                except (TypeError, ValueError):
                    return None

            approval_code = (approval_code or '').strip()
            situation_code = (situation_code or '').strip()
            linha_value = linha or 'OUTROS'

            orders.append({
                'pedido': pedido,
                'lcaseque': lcaseque,
                'cliente_codigo': cliente_codigo,
                'cliente_nome': cliente_nome,
                'cidade': (cidade_nome or '').strip(),
                'estado': (estado_sigla or '').strip(),
                'cidade_uf': cidade_uf,
                'latitude': parse_coord(latitude_raw),
                'longitude': parse_coord(longitude_raw),
                'quantidade_total': quantidade_total,
                'reservado': reservado,
                'separado': separado,
                'carregado': carregado,
                'linha': linha_value,
                'approval_status_code': approval_code,
                'approval_status': ORDER_APPROVAL_STATUS_LABELS.get(approval_code, 'Não Informado'),
                'situation_code': situation_code,
                'situation': ORDER_SITUATION_LABELS.get(situation_code, 'Não Informada'),
                'production_lots_display': production_lots_display or '',
                'kpi_status': kpi_status,
            })

    except Error as e:
        print(f"Erro ao carregar pedidos: {e}")
        error_message = f"Erro ao carregar pedidos: {e}"
    finally:
        if conn:
            conn.close()

    return orders, error_message

def fetch_sales_orders(filters):
    """
    Busca os pedidos de venda com agregados de quantidade, valor, ocorr�ncia e informa��es de lote.
    """
    orders = []
    error_message = None
    conn = get_erp_db_connection()

    if not conn:
        return orders, "Não foi possível conectar ao banco de dados do ERP."

    has_lcapecod_column = table_has_column(conn, 'pedido', 'lcapecod')
    has_peddesval_column = table_has_column(conn, 'pedido', 'peddesval')

    city_expression = (
        "CASE "
        "WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome "
        "WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text "
        "ELSE '' "
        "END"
    )
    state_expression = (
        "CASE "
        "WHEN COALESCE(c.estado, '') <> '' THEN c.estado "
        "WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text "
        "ELSE '' "
        "END"
    )

    load_lot_select = (
        "CAST(p.lcapecod AS TEXT) AS load_lot_code,\n"
        "                COALESCE(lc.lcades, '') AS load_lot_description,\n"
    )
    load_lot_join = "LEFT JOIN lotecar lc ON lc.lcacod = p.lcapecod"

    if not has_lcapecod_column:
        load_lot_select = "NULL AS load_lot_code,\n                '' AS load_lot_description,\n"
        load_lot_join = ""

    if has_peddesval_column:
        valor_total_expression = "COALESCE(pedprod.valor_bruto_total, 0) - COALESCE(p.peddesval, 0)"
        discount_select = (
            "                COALESCE(p.peddesval, 0) AS desconto_total,\n"
            "                COALESCE(pedprod.valor_bruto_total, 0) - COALESCE(p.peddesval, 0) AS valor_total,\n"
        )
    else:
        valor_total_expression = "COALESCE(pedprod.valor_bruto_total, 0)"
        discount_select = (
            "                0 AS desconto_total,\n"
            "                COALESCE(pedprod.valor_bruto_total, 0) AS valor_total,\n"
        )

    valor_total_cast_expression = f"CAST({valor_total_expression} AS TEXT)"
    quantity_total_expression = "COALESCE(pedprod.quantidade_total, 0)"
    quantity_total_cast_expression = f"CAST({quantity_total_expression} AS TEXT)"

    approval_status_label_expression = (
        "CASE UPPER(COALESCE(p.pedaprova, '')) "
        "WHEN 'S' THEN 'Aprovado' "
        "WHEN 'N' THEN 'Não Aprovado' "
        "WHEN 'C' THEN 'Cancelado' "
        "ELSE 'Não Informado' "
        "END"
    )

    situation_label_expression = (
        "CASE UPPER(COALESCE(p.pedsitua, '')) "
        "WHEN 'A' THEN 'Atendido' "
        "WHEN '' THEN 'Em Aberto' "
        "WHEN 'C' THEN 'Cancelado' "
        "WHEN 'P' THEN 'Parcial' "
        "ELSE 'Não Informada' "
        "END"
    )

    try:
        cur = conn.cursor()
        query = f"""
            WITH pedprod AS (
                SELECT
                    pedido,
                    SUM(COALESCE(pprquanti, 0)) AS quantidade_total,
                    SUM(COALESCE(pprvlsoma, 0)) AS valor_bruto_total
                FROM pedprodu
                GROUP BY pedido
            ),
            linha_info AS (
                SELECT
                    sub.pedido,
                    (ARRAY_AGG(sub.linha_value ORDER BY sub.priority))[1] AS linha
                FROM (
                    SELECT DISTINCT
                        base_data.pedido,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 'MADRESILVA'
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 'PETRA'
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 'GARLAND'
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 'GLASSMADRE'
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 'CAVILHAS'
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 'SOLARE'
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 'ESPUMA'
                            ELSE 'OUTROS'
                        END AS linha_value,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 1
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 2
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 3
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 4
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 5
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 6
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 7
                            ELSE 999
                        END AS priority
                    FROM (
                        SELECT
                            pp.pedido,
                            UPPER(COALESCE(g.grunome, '')) AS group_name_upper
                        FROM pedprodu pp
                        LEFT JOIN produto prod ON prod.produto = pp.pprproduto
                        LEFT JOIN grupo g ON g.grupo = prod.grupo
                        WHERE pp.pedido IS NOT NULL
                    ) base_data
                ) sub
                GROUP BY sub.pedido
            ),
            production_lots AS (
                SELECT
                    CAST(lots.pedido AS TEXT) AS pedido,
                    STRING_AGG(lots.lot_display, '; ' ORDER BY lots.lot_display) AS production_lots_display
                FROM (
                    SELECT DISTINCT
                        ao.acaopedi AS pedido,
                        CASE
                            WHEN COALESCE(lp.lotcod::text, '') <> '' THEN
                                lp.lotcod::text ||
                                CASE
                                    WHEN COALESCE(lp.lotdes, '') <> '' THEN ' - ' || lp.lotdes
                                    ELSE ''
                                END
                            ELSE ''
                        END AS lot_display
                    FROM acaorde2 ao
                    JOIN ordem o ON o.ordem = ao.acaoorde
                    LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
                    WHERE ao.acaopedi IS NOT NULL
                ) lots
                WHERE lots.lot_display <> ''
                GROUP BY lots.pedido
            ),
            occurrences AS (
                SELECT DISTINCT ON (peds1ped)
                    CAST(peds1ped AS TEXT) AS pedido,
                    COALESCE(peds1oco::text, '') AS occurrence_code,
                    COALESCE(peds1doco, '') AS occurrence_description
                FROM acompanh
                ORDER BY peds1ped,
                         peds1data DESC NULLS LAST,
                         peds1hora DESC NULLS LAST,
                         peds1seq DESC NULLS LAST,
                         peds1rseq DESC NULLS LAST
            )
            SELECT
                CAST(p.pedido AS TEXT) AS pedido,
                p.peddata,
                COALESCE(p.pedtppvco::text, '') AS codigo,
                COALESCE(e.empnome, '') AS cliente,
                {city_expression} AS cidade,
                {state_expression} AS estado,
                COALESCE(pedprod.quantidade_total, 0) AS quantidade_total,
                COALESCE(pedprod.valor_bruto_total, 0) AS valor_bruto_total,
{discount_select}
                COALESCE(linha.linha, 'OUTROS') AS linha,
                COALESCE(p.pedaprova, '') AS approval_status_code,
                COALESCE(p.pedsitua, '') AS situation_code,
                COALESCE(occ.occurrence_code, '') AS occurrence_code,
                COALESCE(occ.occurrence_description, '') AS occurrence_description,
                COALESCE(prod.production_lots_display, '') AS production_lots_display,
                {load_lot_select}
                COALESCE(v.vendedor::text, '') AS vendor_code,
                COALESCE(v.vennome, '') AS vendor_name
            FROM pedido p
            LEFT JOIN empresa e ON e.empresa = p.pedcliente
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN pedprod ON pedprod.pedido = p.pedido
            LEFT JOIN linha_info linha ON linha.pedido = p.pedido
            LEFT JOIN production_lots prod ON prod.pedido = CAST(p.pedido AS TEXT)
            LEFT JOIN occurrences occ ON occ.pedido = CAST(p.pedido AS TEXT)
            LEFT JOIN vendedor v ON v.vendedor = p.pedrepres
            {load_lot_join}
            WHERE 1 = 1
        """

        params = []

        cities = [value.strip() for value in filters.get('cities', []) if value and value.strip()]
        if cities:
            placeholders = ', '.join(['%s'] * len(cities))
            query += f" AND {city_expression} IN ({placeholders})"
            params.extend(cities)

        states = [value.strip() for value in filters.get('states', []) if value and value.strip()]
        if states:
            placeholders = ', '.join(['%s'] * len(states))
            query += f" AND {state_expression} IN ({placeholders})"
            params.extend(states)

        vendors = [value.strip() for value in filters.get('vendors', []) if value and value.strip()]
        if vendors:
            placeholders = ', '.join(['%s'] * len(vendors))
            query += f" AND COALESCE(p.pedrepres::text, '') IN ({placeholders})"
            params.extend(vendors)

        statuses = [value.strip().upper() for value in filters.get('statuses', []) if value]
        if statuses:
            placeholders = ', '.join(['%s'] * len(statuses))
            query += f" AND COALESCE(p.pedaprova, '') IN ({placeholders})"
            params.extend(statuses)

        situations = [value.strip().upper() for value in filters.get('situations', []) if value]
        if situations:
            placeholders = ', '.join(['%s'] * len(situations))
            query += f" AND COALESCE(p.pedsitua, '') IN ({placeholders})"
            params.extend(situations)

        occurrences_raw = [
            value.strip()
            for value in filters.get('occurrences', [])
            if value and value.strip()
        ]
        occurrence_codes = [
            value for value in occurrences_raw
            if value != OCCURRENCE_BLANK_VALUE
        ]
        include_blank_occurrence = OCCURRENCE_BLANK_VALUE in occurrences_raw
        occurrence_conditions = []
        if occurrence_codes:
            placeholders = ', '.join(['%s'] * len(occurrence_codes))
            occurrence_conditions.append(
                f"COALESCE(occ.occurrence_code, '') IN ({placeholders})"
            )
            params.extend(occurrence_codes)
        if include_blank_occurrence:
            occurrence_conditions.append("COALESCE(occ.occurrence_code, '') = ''")
        if occurrence_conditions:
            query += " AND (" + " OR ".join(occurrence_conditions) + ")"

        has_load_lot = [value.strip().lower() for value in filters.get('has_load_lot', []) if value]
        if has_load_lot:
            wants_yes = 'yes' in has_load_lot
            wants_no = 'no' in has_load_lot
            if wants_yes and not wants_no:
                if has_lcapecod_column:
                    query += " AND p.lcapecod IS NOT NULL"
                else:
                    print("Filtro 'Lote de Carga = Sim' ignorado: coluna 'lcapecod' ausente.")
            elif wants_no and not wants_yes:
                if has_lcapecod_column:
                    query += " AND p.lcapecod IS NULL"
                else:
                    print("Filtro 'Lote de Carga = Não' ignorado: coluna 'lcapecod' ausente.")

        has_production_lot = [value.strip().lower() for value in filters.get('has_production_lot', []) if value]
        if has_production_lot:
            wants_yes = 'yes' in has_production_lot
            wants_no = 'no' in has_production_lot
            if wants_yes and not wants_no:
                query += " AND COALESCE(prod.production_lots_display, '') <> ''"
            elif wants_no and not wants_yes:
                query += " AND COALESCE(prod.production_lots_display, '') = ''"

        def parse_decimal_filter(raw_value):
            if raw_value is None:
                return None
            value = str(raw_value).strip()
            if not value:
                return None
            normalized = value.replace(' ', '')
            if ',' in normalized and '.' in normalized:
                normalized = normalized.replace('.', '').replace(',', '.')
            elif ',' in normalized:
                normalized = normalized.replace(',', '.')
            try:
                return Decimal(normalized)
            except InvalidOperation:
                return None

        pedido_filter = (filters.get('filter_pedido') or '').strip()
        if pedido_filter:
            query += " AND CAST(p.pedido AS TEXT) ILIKE %s"
            params.append(f"%{pedido_filter}%")

        data_filter = (filters.get('filter_data') or '').strip()
        if data_filter:
            like_value = f"%{data_filter}%"
            query += """
                AND (
                    TO_CHAR(p.peddata, 'DD/MM/YYYY') ILIKE %s
                    OR CAST(p.peddata AS TEXT) ILIKE %s
                )
            """
            params.extend([like_value, like_value])

        codigo_filter = (filters.get('filter_codigo') or '').strip()
        if codigo_filter:
            query += " AND COALESCE(p.pedtppvco::text, '') ILIKE %s"
            params.append(f"%{codigo_filter}%")

        cliente_filter = (filters.get('filter_cliente') or '').strip()
        if cliente_filter:
            query += " AND COALESCE(e.empnome, '') ILIKE %s"
            params.append(f"%{cliente_filter}%")

        quantidade_filter = parse_decimal_filter(filters.get('filter_quantidade_total'))
        if quantidade_filter is not None:
            query += f" AND {quantity_total_expression} = %s"
            params.append(quantidade_filter)

        valor_total_filter = parse_decimal_filter(filters.get('filter_valor_total'))
        if valor_total_filter is not None:
            query += f" AND {valor_total_expression} = %s"
            params.append(valor_total_filter)

        linha_filter = (filters.get('filter_linha') or '').strip()
        if linha_filter:
            query += " AND COALESCE(linha.linha, 'OUTROS') ILIKE %s"
            params.append(f"%{linha_filter}%")

        approval_status_filter = (filters.get('filter_approval_status') or '').strip()
        if approval_status_filter:
            like_value = f"%{approval_status_filter}%"
            query += f" AND (({approval_status_label_expression}) ILIKE %s OR COALESCE(p.pedaprova, '') ILIKE %s)"
            params.extend([like_value, like_value])

        situation_filter = (filters.get('filter_situation') or '').strip()
        if situation_filter:
            like_value = f"%{situation_filter}%"
            query += f" AND (({situation_label_expression}) ILIKE %s OR COALESCE(p.pedsitua, '') ILIKE %s)"
            params.extend([like_value, like_value])

        occurrence_filter = (filters.get('filter_occurrence') or '').strip()
        if occurrence_filter:
            like_value = f"%{occurrence_filter}%"
            query += """
                AND (
                    COALESCE(occ.occurrence_code, '') ILIKE %s
                    OR COALESCE(occ.occurrence_description, '') ILIKE %s
                    OR (
                        COALESCE(occ.occurrence_code, '') <> ''
                        AND COALESCE(occ.occurrence_description, '') <> ''
                        AND (COALESCE(occ.occurrence_code, '') || ' - ' || COALESCE(occ.occurrence_description, '')) ILIKE %s
                    )
                )
            """
            params.extend([like_value, like_value, like_value])

        production_lots_filter = (filters.get('filter_production_lots_display') or '').strip()
        if production_lots_filter:
            query += " AND COALESCE(prod.production_lots_display, '') ILIKE %s"
            params.append(f"%{production_lots_filter}%")

        load_lot_filter = (filters.get('filter_load_lot') or '').strip()
        if load_lot_filter:
            if has_lcapecod_column:
                query += " AND (CAST(p.lcapecod AS TEXT) ILIKE %s OR COALESCE(lc.lcades, '') ILIKE %s)"
                like_pattern = f"%{load_lot_filter}%"
                params.extend([like_pattern, like_pattern])
            else:
                print("Filtro de coluna 'Lote Carga' ignorado: coluna 'lcapecod' ausente.")

        start_date_str = (filters.get('start_date') or '').strip()
        if start_date_str:
            try:
                start_date = datetime.datetime.strptime(start_date_str, '%Y-%m-%d').date()
                query += " AND p.peddata >= %s"
                params.append(start_date)
            except ValueError:
                print(f"Filtro de data inicial inv�lido: {start_date_str}")

        end_date_str = (filters.get('end_date') or '').strip()
        if end_date_str:
            try:
                end_date = datetime.datetime.strptime(end_date_str, '%Y-%m-%d').date()
                query += " AND p.peddata <= %s"
                params.append(end_date)
            except ValueError:
                print(f"Filtro de data final inv�lido: {end_date_str}")

        query += " ORDER BY p.peddata DESC NULLS LAST, CAST(p.pedido AS TEXT) DESC"

        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            (
                pedido,
                peddata,
                codigo,
                cliente,
                cidade,
                estado,
                quantidade_total_raw,
                valor_bruto_raw,
                desconto_raw,
                valor_total_raw,
                linha,
                approval_status_code,
                situation_code,
                occurrence_code,
                occurrence_description,
                production_lots_display,
                load_lot_code,
                load_lot_description,
                vendor_code,
                vendor_name,
            ) = row

            try:
                quantidade_total = float(quantidade_total_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                quantidade_total = 0.0

            try:
                valor_total = float(valor_total_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_total = 0.0

            load_lot_value = ''
            if load_lot_code:
                load_lot_value = str(load_lot_code)
                if load_lot_description:
                    load_lot_value = f"{load_lot_value} - {load_lot_description}"

            occurrence_display = ''
            if occurrence_code and occurrence_description:
                occurrence_display = f"{occurrence_code} - {occurrence_description}"
            elif occurrence_code:
                occurrence_display = occurrence_code
            elif occurrence_description:
                occurrence_display = occurrence_description

            data_pedido = ''
            if isinstance(peddata, (datetime.date, datetime.datetime)):
                data_pedido = peddata.strftime('%d/%m/%Y')
            elif peddata:
                data_pedido = str(peddata)

            orders.append(
                {
                    'pedido': pedido or '',
                    'data': data_pedido,
                    'codigo': codigo or '',
                    'cliente': cliente or '',
                    'cidade': cidade or '',
                    'estado': estado or '',
                    'quantidade_total': quantidade_total,
                    'valor_total': valor_total,
                    'linha': linha or 'OUTROS',
                    'approval_status_code': approval_status_code or '',
                    'approval_status': ORDER_APPROVAL_STATUS_LABELS.get(
                        (approval_status_code or '').strip(), 'Não Informado'
                    ),
                    'situation_code': situation_code or '',
                    'situation': ORDER_SITUATION_LABELS.get(
                        (situation_code or '').strip(), 'Não Informada'
                    ),
                    'occurrence_code': occurrence_code or '',
                    'occurrence': occurrence_display,
                    'production_lots_display': production_lots_display or '',
                    'load_lot': load_lot_value,
                    'vendor_code': vendor_code or '',
                    'vendor_name': vendor_name or '',
                }
            )

    except Error as e:
        print(f"Erro ao carregar pedidos de venda: {e}")
        error_message = f"Erro ao carregar pedidos de venda: {e}"
    finally:
        if conn:
            conn.close()

    return orders, error_message


def fetch_orders_from_integrated_view(filters):
    """
    Busca pedidos para o Mapa Interativo 2 utilizando a view vw_siga_integrated_documents no siga_db.
    Parâmetros esperados em filters seguem a mesma convenção do fetch_orders tradicional.
    """
    orders = []
    error_message = None
    conn = get_siga_db_connection()

    if not conn:
        return orders, "Não foi possível conectar ao banco de dados auxiliar (siga_db)."

    record_type_priority = {
        'pedidos_vendas': 3,
        'consulta_pedidos': 2,
        'assistencia_tecnica': 1,
    }

    def normalize_record_type(value):
        if not value:
            return ''
        return str(value).strip().lower()

    def build_order_unique_key(record_type, document_id_text):
        document_id_value = (document_id_text or '').strip()
        if not document_id_value:
            return ''
        normalized_type = normalize_record_type(record_type)
        if normalized_type == 'assistencia_tecnica':
            return f'assistencia_tecnica:{document_id_value}'
        if normalized_type in {'consulta_pedidos', 'pedidos_vendas'}:
            return f'pedido:{document_id_value}'
        fallback_type = normalized_type or 'registro'
        return f'{fallback_type}:{document_id_value}'

    def has_load_lot(payload):
        return bool((payload.get('load_lot_code') or '').strip())

    def has_production_lot(payload):
        return bool((payload.get('production_lots_display') or '').strip())

    def stage_data_score(payload):
        score = 0
        if not isinstance(payload, dict):
            return score
        presence = payload.get('_stage_presence')
        if isinstance(presence, dict):
            for key in ('reservado', 'separado', 'carregado'):
                if presence.get(key):
                    score += 1
            return score
        for key in ('reservado', 'separado', 'carregado'):
            value = payload.get(key)
            if value is None:
                continue
            try:
                float(value)
            except (TypeError, ValueError):
                continue
            score += 1
        return score

    def extract_date(value):
        if isinstance(value, datetime.datetime):
            return value.date()
        if isinstance(value, datetime.date):
            return value
        return None

    def build_order_rank(payload):
        stage_score = stage_data_score(payload)
        type_score = record_type_priority.get(
            normalize_record_type((payload or {}).get('record_type')),
            0,
        )
        coordinate_score = 1 if has_valid_coordinates(payload or {}) else 0
        load_score = 1 if has_load_lot(payload or {}) else 0
        lot_score = 1 if has_production_lot(payload or {}) else 0
        date_value = extract_date((payload or {}).get('document_date')) or datetime.date.min
        return (
            stage_score,
            type_score,
            coordinate_score,
            load_score,
            lot_score,
            date_value,
        )

    def merge_stage_data(preferred, fallback):
        if not preferred or not fallback:
            return preferred
        stage_keys = ('reservado', 'separado', 'carregado')
        preferred_presence = preferred.get('_stage_presence') or {}
        fallback_presence = fallback.get('_stage_presence') or {}
        for key in stage_keys:
            has_preferred = bool(preferred_presence.get(key))
            has_fallback = bool(fallback_presence.get(key))
            if not has_preferred and has_fallback:
                preferred[key] = fallback.get(key)
                preferred_presence[key] = True
        preferred['_stage_presence'] = preferred_presence
        return preferred

    def should_replace_order(existing, candidate):
        if not existing:
            return True

        existing_rank = build_order_rank(existing)
        candidate_rank = build_order_rank(candidate)
        if candidate_rank == existing_rank:
            return False
        return candidate_rank > existing_rank

    record_types = filters.get('record_types') or []
    if not record_types:
        record_types = ['consulta_pedidos']

    if isinstance(record_types, str):
        record_types = [record_types]

    normalized_types = []
    for value in record_types:
        if not value:
            continue
        text = str(value).strip().lower()
        if text in {'consulta_pedidos', 'pedidos_vendas', 'assistencia_tecnica'}:
            normalized_types.append(text)
    if not normalized_types:
        normalized_types = ['consulta_pedidos']
    includes_assistance = 'assistencia_tecnica' in normalized_types

    sort_by = (filters.get('sort_by') or 'pedido').strip()
    sort_order = (filters.get('sort_order') or 'desc').strip().lower()
    if sort_order not in {'asc', 'desc'}:
        sort_order = 'desc'

    sort_column_map = {
        'pedido': 'document_id',
        'cliente_codigo': 'customer_code',
        'cliente_nome': 'customer_name',
        'cidade_uf': 'city',
        'quantidade_total': 'quantity_total',
        'reservado': 'reserved',
        'separado': 'separated',
        'carregado': 'loaded',
        'linha': 'line',
        'data_documento': 'document_date',
    }
    sort_column = sort_column_map.get(sort_by, 'document_id')
    sort_direction = 'ASC' if sort_order == 'asc' else 'DESC'

    try:
        cur = conn.cursor()
        order_positions = {}
        row_counter = 0
        base_query = [
            "SELECT",
            "    record_type,",
            "    document_id,",
            "    document_date,",
            "    customer_code,",
            "    customer_name,",
            "    city,",
            "    state,",
            "    latitude,",
            "    longitude,",
            "    quantity_total,",
            "    reserved,",
            "    separated,",
            "    loaded,",
            "    line,",
            "    approval_status_code,",
            "    situation_code,",
            "    production_lots_display,",
            "    load_lot_code,",
            "    load_lot_description,",
            "    kpi_status",
            "FROM vw_siga_integrated_documents",
            "WHERE record_type = ANY(%s)",
        ]
        params = [normalized_types]

        start_date = (filters.get('start_date') or '').strip()
        if start_date:
            try:
                datetime.datetime.strptime(start_date, '%Y-%m-%d')
                base_query.append("AND document_date >= %s")
                params.append(start_date)
            except ValueError:
                pass

        end_date = (filters.get('end_date') or '').strip()
        if end_date:
            try:
                datetime.datetime.strptime(end_date, '%Y-%m-%d')
                base_query.append("AND document_date <= %s")
                params.append(end_date)
            except ValueError:
                pass

        load_lots = filters.get('load_lots') or []
        if isinstance(load_lots, str):
            load_lots = [load_lots]
        load_lots = [value.strip() for value in load_lots if value and value.strip()]
        if load_lots:
            base_query.append("AND COALESCE(load_lot_code, '') ILIKE ANY(%s)")
            params.append([f"%{value}%" for value in load_lots])

        single_load_lot = (filters.get('load_lot') or '').strip()
        if single_load_lot:
            pattern = f"%{single_load_lot}%"
            base_query.append("AND (COALESCE(load_lot_code, '') ILIKE %s OR COALESCE(load_lot_description, '') ILIKE %s)")
            params.extend([pattern, pattern])

        production_lots = filters.get('production_lots') or []
        if isinstance(production_lots, str):
            production_lots = [production_lots]
        production_lots = [value.strip() for value in production_lots if value and value.strip()]
        if production_lots:
            patterns = [f"%{value}%" for value in production_lots]
            if includes_assistance:
                base_query.append(
                    "AND ((record_type <> 'assistencia_tecnica' AND COALESCE(production_lots_display, '') <> '' "
                    "AND COALESCE(production_lots_display, '') ILIKE ANY(%s)) OR record_type = 'assistencia_tecnica')"
                )
            else:
                base_query.append(
                    "AND (COALESCE(production_lots_display, '') <> '' AND COALESCE(production_lots_display, '') ILIKE ANY(%s))"
                )
            params.append(patterns)

        approval_statuses = filters.get('approval_statuses') or []
        if approval_statuses:
            normalized = [code.strip().upper() for code in approval_statuses if code]
            normalized = [code for code in normalized if code in MAP_APPROVAL_STATUS_CODES]
            if normalized:
                base_query.append("AND UPPER(COALESCE(approval_status_code, '')) = ANY(%s)")
                params.append(normalized)

        situations = filters.get('situations') or []
        if situations:
            normalized = [code.strip().upper() for code in situations if code is not None]
            normalized = [code for code in normalized if code in MAP_SITUATION_CODES]
            if normalized:
                base_query.append("AND UPPER(COALESCE(situation_code, '')) = ANY(%s)")
                params.append(normalized)

        lines = filters.get('lines') or []
        if isinstance(lines, str):
            lines = [lines]
        lines = [value.strip() for value in lines if value and value.strip()]
        if lines:
            base_query.append("AND COALESCE(line, '') ILIKE ANY(%s)")
            params.append([value for value in lines])
        elif filters.get('line'):
            value = (filters['line'] or '').strip()
            if value:
                base_query.append("AND COALESCE(line, '') ILIKE %s")
                params.append(f"%{value}%")

        base_query.append(f"ORDER BY {sort_column} {sort_direction}, document_id DESC")

        cur.execute("\n".join(base_query), tuple(params))
        rows = cur.fetchall()

        for row in rows:
            row_counter += 1
            (
                record_type,
                document_id,
                document_date,
                customer_code,
                customer_name,
                city,
                state,
                latitude,
                longitude,
                quantity_total,
                reserved,
                separated,
                loaded,
                line_value,
                approval_code,
                situation_code,
                production_lots_display,
                load_lot_code,
                load_lot_description,
                kpi_status_raw,
            ) = row

            record_type = (record_type or '').strip().lower()
            if record_type not in RECORD_TYPE_LABELS:
                record_type = 'consulta_pedidos'
            record_type_label = RECORD_TYPE_LABELS.get(record_type, 'Registro')

            document_id_text = ''
            if document_id is not None:
                try:
                    document_id_text = str(document_id).strip()
                except (TypeError, ValueError):
                    document_id_text = ''
            if not document_id_text:
                document_id_text = str(document_id or '').strip()
            if not document_id_text:
                document_id_text = str(row_counter)

            try:
                pedido = int(document_id_text)
            except (TypeError, ValueError):
                pedido = document_id_text
            unique_key = build_order_unique_key(record_type, document_id_text)
            unique_id = unique_key or f"{record_type}:{document_id_text}"
            can_show_details = record_type != 'assistencia_tecnica'

            try:
                quantidade = float(quantity_total) if quantity_total is not None else 0.0
            except (TypeError, ValueError):
                quantidade = 0.0

            has_reservado_value = reserved is not None
            try:
                reservado = float(reserved) if reserved is not None else 0.0
            except (TypeError, ValueError):
                reservado = 0.0

            has_separado_value = separated is not None
            try:
                separado = float(separated) if separated is not None else 0.0
            except (TypeError, ValueError):
                separado = 0.0

            has_carregado_value = loaded is not None
            try:
                carregado = float(loaded) if loaded is not None else 0.0
            except (TypeError, ValueError):
                carregado = 0.0

            latitude_value = None
            longitude_value = None
            try:
                latitude_value = float(latitude) if latitude is not None else None
            except (TypeError, ValueError):
                latitude_value = None
            try:
                longitude_value = float(longitude) if longitude is not None else None
            except (TypeError, ValueError):
                longitude_value = None

            kpi_status = kpi_status_raw
            if kpi_status is None:
                kpi_status = calculate_order_kpi(reservado, separado, carregado)

            approval_code = (approval_code or '').strip()
            situation_code = (situation_code or '').strip()
            if record_type == 'assistencia_tecnica':
                approval_label = get_technical_assistance_status_label(approval_code)
                situation_label = get_technical_assistance_situation_label(situation_code)
            else:
                approval_label = ORDER_APPROVAL_STATUS_LABELS.get(approval_code, 'Não Informado')
                situation_label = ORDER_SITUATION_LABELS.get(situation_code, 'Não Informada')

            city_value = (city or '').strip()
            state_value = (state or '').strip()
            if city_value and state_value:
                cidade_uf_value = f"{city_value}/{state_value}"
            else:
                cidade_uf_value = city_value or state_value or ''

            order_payload = {
                'record_type': record_type,
                'record_type_label': record_type_label,
                'unique_id': unique_id,
                'can_show_details': can_show_details,
                'pedido': pedido,
                'document_id': document_id_text,
                'document_date': document_date,
                'cliente_codigo': customer_code,
                'cliente_nome': customer_name,
                'cidade': city_value,
                'estado': state_value,
                'cidade_uf': cidade_uf_value,
                'lcaseque': '',
                'latitude': latitude_value,
                'longitude': longitude_value,
                'quantidade_total': quantidade,
                'reservado': reservado,
                'separado': separado,
                'carregado': carregado,
                'linha': line_value or 'OUTROS',
                'approval_status_code': approval_code,
                'approval_status': approval_label,
                'situation_code': situation_code,
                'situation': situation_label,
                'production_lots_display': production_lots_display or '',
                'load_lot_code': load_lot_code or '',
                'load_lot_description': load_lot_description or '',
                'kpi_status': kpi_status,
                '_stage_presence': {
                    'reservado': has_reservado_value,
                    'separado': has_separado_value,
                    'carregado': has_carregado_value,
                },
            }

            existing_index = order_positions.get(unique_id)
            if existing_index is None:
                order_positions[unique_id] = len(orders)
                orders.append(order_payload)
            else:
                existing_payload = orders[existing_index]
                if should_replace_order(existing_payload, order_payload):
                    orders[existing_index] = merge_stage_data(order_payload, existing_payload)
                else:
                    orders[existing_index] = merge_stage_data(existing_payload, order_payload)

        if orders:
            missing_codes = []
            seen_codes = set()
            for order in orders:
                lat_value = normalize_coordinate_value(order.get('latitude'))
                lon_value = normalize_coordinate_value(order.get('longitude'))
                if (
                    lat_value is not None and lon_value is not None
                    and not isclose(lat_value, 0.0, abs_tol=1e-6)
                    and not isclose(lon_value, 0.0, abs_tol=1e-6)
                ):
                    continue
                code_text = str(order.get('cliente_codigo') or '').strip()
                if code_text and code_text not in seen_codes:
                    seen_codes.add(code_text)
                    missing_codes.append(code_text)

            if missing_codes:
                fallback_coordinates = fetch_customer_coordinates_from_observations(missing_codes)
                if fallback_coordinates:
                    for order in orders:
                        code_text = str(order.get('cliente_codigo') or '').strip()
                        if not code_text:
                            continue
                        fallback_coord = fallback_coordinates.get(code_text)
                        if not fallback_coord:
                            continue

                        lat_value = normalize_coordinate_value(order.get('latitude'))
                        lon_value = normalize_coordinate_value(order.get('longitude'))
                        if (
                            lat_value is not None and lon_value is not None
                            and not isclose(lat_value, 0.0, abs_tol=1e-6)
                            and not isclose(lon_value, 0.0, abs_tol=1e-6)
                        ):
                            continue

                        order['latitude'] = fallback_coord['latitude']
                        order['longitude'] = fallback_coord['longitude']
                        order['coordinate_source'] = 'customer_observation'

        assistance_identifiers = [
            str(order.get('pedido') or order.get('document_id') or '').strip()
            for order in orders
            if (order.get('record_type') or '').strip().lower() == 'assistencia_tecnica'
        ]
        assistance_identifiers = [code for code in assistance_identifiers if code]
        if assistance_identifiers:
            assistance_metrics = fetch_assistance_operational_metrics(assistance_identifiers)
            if assistance_metrics:
                def to_float(value):
                    if value in (None, ''):
                        return 0.0
                    try:
                        return float(value)
                    except (TypeError, ValueError, InvalidOperation):
                        try:
                            return float(Decimal(str(value)))
                        except (TypeError, ValueError, InvalidOperation):
                            return 0.0

                for order in orders:
                    if (order.get('record_type') or '').strip().lower() != 'assistencia_tecnica':
                        continue
                    key = str(order.get('pedido') or order.get('document_id') or '').strip()
                    if not key:
                        continue
                    metrics = assistance_metrics.get(key)
                    if not metrics:
                        continue
                    order['reservado'] = to_float(metrics.get('reservado'))
                    order['separado'] = to_float(metrics.get('separado'))
                    order['carregado'] = to_float(metrics.get('carregado'))
                    metrics_line = (metrics.get('linha') or '').strip()
                    if metrics_line:
                        current_line = str(order.get('linha') or '').strip()
                        if not current_line or current_line.upper() == 'OUTROS':
                            order['linha'] = metrics_line

            production_lot_map = fetch_assistance_production_lots(assistance_identifiers)
            if production_lot_map:
                for order in orders:
                    if (order.get('record_type') or '').strip().lower() != 'assistencia_tecnica':
                        continue
                    key = str(order.get('pedido') or order.get('document_id') or '').strip()
                    if not key:
                        continue
                    lot_display = production_lot_map.get(key)
                    if not lot_display:
                        continue
                    existing_display = (order.get('production_lots_display') or '').strip()
                    if existing_display:
                        combined = []
                        for value in existing_display.split(';'):
                            cleaned = value.strip()
                            if cleaned and cleaned not in combined:
                                combined.append(cleaned)
                        for value in lot_display.split(';'):
                            cleaned = value.strip()
                            if cleaned and cleaned not in combined:
                                combined.append(cleaned)
                        order['production_lots_display'] = '; '.join(combined)
                    else:
                        order['production_lots_display'] = lot_display

        enrich_orders_with_sequence_and_city(orders)
    except Error as exc:
        print(f"Erro ao carregar pedidos via view integrada: {exc}")
        error_message = f"Erro ao carregar pedidos via view integrada: {exc}"
    finally:
        if conn:
            conn.close()

    return orders, error_message


def enrich_orders_with_sequence_and_city(orders):
    """
    Complementa os pedidos carregados via view integrada com a sequência
    (lcaseque) e com a melhor combinação Cidade/UF obtida diretamente do ERP.
    """
    if not orders:
        return

    order_map = {}
    for order in orders:
        record_type = (order.get('record_type') or '').strip().lower()
        if record_type not in {'consulta_pedidos', 'pedidos_vendas'}:
            continue
        identifier = str(order.get('pedido') or order.get('document_id') or '').strip()
        if not identifier:
            continue
        if identifier not in order_map:
            order_map[identifier] = order

    if not order_map:
        return

    conn = get_erp_db_connection()
    if not conn:
        return

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT
                CAST(p.pedido AS TEXT) AS pedido_id,
                COALESCE(p.lcaseque::text, '') AS sequencia,
                COALESCE(
                    NULLIF(TRIM(c.cidnome), ''),
                    NULLIF(TRIM(emp_city.cidnome), ''),
                    NULLIF(TRIM(p.pedentcid::text), ''),
                    ''
                ) AS cidade,
                COALESCE(
                    NULLIF(TRIM(c.estado), ''),
                    NULLIF(TRIM(emp_city.estado), ''),
                    NULLIF(TRIM(p.pedentuf::text), ''),
                    ''
                ) AS estado
            FROM pedido p
            LEFT JOIN empresa emp ON emp.empresa = p.pedcliente
            LEFT JOIN cidade c ON c.cidade = p.pedentcid
            LEFT JOIN cidade emp_city ON emp_city.cidade = emp.empcidade
            WHERE CAST(p.pedido AS TEXT) = ANY(%s)
            """,
            (list(order_map.keys()),)
        )

        for pedido_id, sequencia, cidade, estado in cur.fetchall():
            key = (pedido_id or '').strip()
            if not key:
                continue
            order = order_map.get(key)
            if not order:
                continue

            sequence_value = (sequencia or '').strip()
            order['lcaseque'] = sequence_value

            city_value = (cidade or '').strip()
            state_value = (estado or '').strip()

            if city_value:
                order['cidade'] = city_value
            if state_value:
                order['estado'] = state_value

            if city_value and state_value:
                order['cidade_uf'] = f"{city_value}/{state_value}"
            elif city_value or state_value:
                order['cidade_uf'] = city_value or state_value
            else:
                existing_city = (order.get('cidade') or '').strip()
                existing_state = (order.get('estado') or '').strip()
                if existing_city and existing_state:
                    order['cidade_uf'] = f"{existing_city}/{existing_state}"
                else:
                    order['cidade_uf'] = existing_city or existing_state or ''
    except Error as exc:
        print(f"Não foi possível enriquecer pedidos com dados de sequência/cidade: {exc}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def fetch_assistance_production_lots(assistance_codes):
    """
    Localiza os lotes de produção associados às assistências técnicas informadas.
    Retorna um dicionário {codigo_assistencia: 'lote - descrição'}.
    """
    normalized = []
    seen = set()
    for code in assistance_codes or []:
        text = str(code or '').strip()
        if not text:
            continue
        if text in seen:
            continue
        seen.add(text)
        normalized.append(text)

    if not normalized:
        return {}

    production_lot_map = {}
    conn = get_erp_db_connection()
    if not conn:
        return production_lot_map

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT
                ao.acaorasco::text AS assistance_code,
                TRIM(COALESCE(o.lotcod::text, '')) AS lot_code,
                TRIM(COALESCE(lp.lotdes, '')) AS lot_description
            FROM acaorde4 ao
            INNER JOIN ordem o ON o.ordem = ao.acaoorde
            LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
            WHERE ao.acaorasco::text = ANY(%s)
              AND TRIM(COALESCE(o.lotcod::text, '')) <> ''
            """,
            (normalized,),
        )

        aggregated = {}
        for assistance_code, lot_code, lot_description in cur.fetchall():
            assistance_key = (assistance_code or '').strip()
            lot_code = (lot_code or '').strip()
            lot_description = (lot_description or '').strip()
            if not assistance_key or not lot_code:
                continue
            label = lot_code
            if lot_description:
                label = f"{lot_code} - {lot_description}"
            entries = aggregated.setdefault(assistance_key, [])
            if label not in entries:
                entries.append(label)

        for assistance_code, labels in aggregated.items():
            production_lot_map[assistance_code] = '; '.join(labels)
    except (Exception, Error) as error:
        print(f"Erro ao carregar lotes de produção das assistências: {error}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return production_lot_map


def fetch_assistance_operational_metrics(assistance_codes):
    """
    Recupera métricas operacionais (reservado, separado, carregado e linha)
    diretamente do banco do ERP para as assistências informadas.
    """
    normalized = []
    for code in assistance_codes or []:
        text = str(code or '').strip()
        if text:
            normalized.append(text)

    if not normalized:
        return {}

    metrics = {}

    def ensure_entry(code):
        entry = metrics.get(code)
        if not entry:
            entry = {
                'reservado': Decimal('0'),
                'separado': Decimal('0'),
                'carregado': Decimal('0'),
                'linha': '',
            }
            metrics[code] = entry
        return entry

    conn = get_erp_db_connection()
    if not conn:
        return metrics

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT
                TRIM(CAST(pm.prjmpedid AS TEXT)) AS assistance_id,
                SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'R' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS reservado,
                SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'P' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS separado,
                SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'C' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS carregado
            FROM projmovi pm
            INNER JOIN assiste1 ai ON TRIM(CAST(ai.assistec AS TEXT)) = TRIM(CAST(pm.prjmpedid AS TEXT))
                                   AND TRIM(CAST(ai.aspproduto AS TEXT)) = TRIM(CAST(pm.prjmproex AS TEXT))
            WHERE pm.prjmpedid IS NOT NULL
              AND TRIM(CAST(pm.prjmpedid AS TEXT)) = ANY(%s)
            GROUP BY TRIM(CAST(pm.prjmpedid AS TEXT))
            """,
            (normalized,),
        )

        for assistance_id, reserved, separated, loaded in cur.fetchall():
            key = (assistance_id or '').strip()
            if not key:
                continue
            entry = ensure_entry(key)
            try:
                entry['reservado'] = Decimal(reserved or 0)
            except (TypeError, InvalidOperation):
                entry['reservado'] = Decimal('0')
            try:
                entry['separado'] = Decimal(separated or 0)
            except (TypeError, InvalidOperation):
                entry['separado'] = Decimal('0')
            try:
                entry['carregado'] = Decimal(loaded or 0)
            except (TypeError, InvalidOperation):
                entry['carregado'] = Decimal('0')

        cur.execute(
            """
            SELECT
                TRIM(CAST(sub.assistec AS TEXT)) AS assistance_id,
                (ARRAY_AGG(sub.linha_value ORDER BY sub.priority))[1] AS linha
            FROM (
                SELECT DISTINCT
                    TRIM(CAST(base_data.assistec AS TEXT)) AS assistec,
                    CASE
                        WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 'MADRESILVA'
                        WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 'PETRA'
                        WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 'GARLAND'
                        WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 'GLASSMADRE'
                        WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 'CAVILHAS'
                        WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 'SOLARE'
                        WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 'ESPUMA'
                        ELSE 'OUTROS'
                    END AS linha_value,
                    CASE
                        WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 1
                        WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 2
                        WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 3
                        WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 4
                        WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 5
                        WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 6
                        WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 7
                        ELSE 999
                    END AS priority
                FROM (
                    SELECT
                        ai.assistec,
                        UPPER(COALESCE(g.grunome, '')) AS group_name_upper
                    FROM assiste1 ai
                    LEFT JOIN produto prod ON prod.produto = ai.aspproduto
                    LEFT JOIN grupo g ON g.grupo = prod.grupo
                    WHERE ai.assistec IS NOT NULL
                      AND TRIM(CAST(ai.assistec AS TEXT)) = ANY(%s)
                ) base_data
            ) sub
            GROUP BY TRIM(CAST(sub.assistec AS TEXT))
            """,
            (normalized,),
        )

        for assistance_id, linha in cur.fetchall():
            key = (assistance_id or '').strip()
            if not key:
                continue
            entry = ensure_entry(key)
            entry['linha'] = (linha or '').strip()
    except (Exception, Error) as error:
        print(f"Erro ao carregar métricas de assistência: {error}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return metrics


def fetch_technical_assistance(filters):
    """
    Busca as assistências técnicas com filtros opcionais.
    """
    records = []
    error_message = None
    conn = get_erp_db_connection()

    if not conn:
        return records, "Não foi possível conectar ao banco de dados do ERP."

    cur = None
    try:
        cur = conn.cursor()
        query = """
            WITH proj_totals AS (
                SELECT
                    TRIM(CAST(pm.prjmpedid AS TEXT)) AS assistec,
                    SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'R' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS reservado,
                    SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'P' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS separado,
                    SUM(CASE WHEN TRIM(UPPER(pm.prjmovtip)) = 'C' THEN COALESCE(pm.prjmquant, 0) ELSE 0 END) AS carregado
                FROM projmovi pm
                INNER JOIN assiste1 ai ON TRIM(CAST(ai.assistec AS TEXT)) = TRIM(CAST(pm.prjmpedid AS TEXT))
                                       AND TRIM(CAST(ai.aspproduto AS TEXT)) = TRIM(CAST(pm.prjmproex AS TEXT))
                WHERE pm.prjmpedid IS NOT NULL
                GROUP BY TRIM(CAST(pm.prjmpedid AS TEXT))
            ),
            linha_info AS (
                SELECT
                    TRIM(CAST(sub.assistec AS TEXT)) AS assistec,
                    (ARRAY_AGG(sub.linha_value ORDER BY sub.priority))[1] AS linha
                FROM (
                    SELECT DISTINCT
                        base_data.assistec,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 'MADRESILVA'
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 'PETRA'
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 'GARLAND'
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 'GLASSMADRE'
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 'CAVILHAS'
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 'SOLARE'
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 'ESPUMA'
                            ELSE 'OUTROS'
                        END AS linha_value,
                        CASE
                            WHEN POSITION('MADRESILVA' IN base_data.group_name_upper) > 0 OR POSITION('* M.' IN base_data.group_name_upper) > 0 THEN 1
                            WHEN POSITION('PETRA' IN base_data.group_name_upper) > 0 OR POSITION('* P.' IN base_data.group_name_upper) > 0 THEN 2
                            WHEN POSITION('GARLAND' IN base_data.group_name_upper) > 0 OR POSITION('* G.' IN base_data.group_name_upper) > 0 THEN 3
                            WHEN POSITION('GLASS' IN base_data.group_name_upper) > 0 OR POSITION('* V.' IN base_data.group_name_upper) > 0 THEN 4
                            WHEN POSITION('CAVILHAS' IN base_data.group_name_upper) > 0 THEN 5
                            WHEN POSITION('SOLARE' IN base_data.group_name_upper) > 0 OR POSITION('* S.' IN base_data.group_name_upper) > 0 THEN 6
                            WHEN POSITION('ESPUMA' IN base_data.group_name_upper) > 0 OR POSITION('* ESPUMA' IN base_data.group_name_upper) > 0 THEN 7
                            ELSE 999
                        END AS priority
                    FROM (
                        SELECT
                            ai.assistec,
                            UPPER(COALESCE(g.grunome, '')) AS group_name_upper
                        FROM assiste1 ai
                        LEFT JOIN produto prod ON prod.produto = ai.aspproduto
                        LEFT JOIN grupo g ON g.grupo = prod.grupo
                        WHERE ai.assistec IS NOT NULL
                    ) base_data
                ) sub
                GROUP BY TRIM(CAST(sub.assistec AS TEXT))
            )
            SELECT
                a.assistec,
                a.asscliente,
                COALESCE(e.empnome, '') AS cliente_nome,
                COALESCE(cid.cidnome, '') AS cidade_nome,
                COALESCE(cid.estado, '') AS estado_sigla,
                a.assrepres,
                COALESCE(v.vennome, '') AS representante_nome,
                COALESCE(resp.responsavel_nome, '') AS responsavel_nome,
                a.assdata,
                a.assstatus,
                a.asssitua,
                COALESCE(a.assobs1, '') AS observacao,
                COALESCE(a.assnurep, '') AS numero_reparo,
                COALESCE(a.asstipo, '') AS tipo,
                a.assdtalt,
                a.asshralt,
                COALESCE(a.assusualt, '') AS usuario_alteracao,
                COALESCE(SUM(i.aspquanti), 0) AS quantidade_pecas,
                COALESCE(SUM(i.asptotal), 0) AS valor_total,
                COUNT(DISTINCT i.aspseq) AS total_itens,
                COALESCE(pt.reservado, 0) AS reservado,
                COALESCE(pt.separado, 0) AS separado,
                COALESCE(pt.carregado, 0) AS carregado,
                COALESCE(li.linha, '') AS linha
            FROM assistec a
            LEFT JOIN assiste1 i ON i.assistec = a.assistec
            LEFT JOIN empresa e ON e.empresa = a.asscliente
            LEFT JOIN cidade cid ON cid.cidade = e.empcidade
            LEFT JOIN vendedor v ON v.vendedor = a.assrepres
            LEFT JOIN proj_totals pt ON pt.assistec = TRIM(CAST(a.assistec AS TEXT))
            LEFT JOIN linha_info li ON li.assistec = TRIM(CAST(a.assistec AS TEXT))
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(TRIM(tinsp.tinspdesc::text), '') AS responsavel_nome
                FROM assdadt ad
                LEFT JOIN tinspte1 tinsp ON COALESCE(TRIM(ad.asdtcleg::text), '') = COALESCE(TRIM(tinsp.tinspdesc::text), '')
                WHERE CAST(ad.asdtcod AS TEXT) = CAST(a.assistec AS TEXT)
                ORDER BY ad.asdtcod
                LIMIT 1
            ) resp ON TRUE
            WHERE 1 = 1
        """
        params = []

        start_date = filters.get('start_date')
        if start_date:
            query += " AND a.assdata >= %s"
            params.append(start_date)

        end_date = filters.get('end_date')
        if end_date:
            query += " AND a.assdata <= %s"
            params.append(end_date)

        statuses = filters.get('statuses') or []
        normalized_statuses = [
            normalize_lookup_code(value) for value in statuses if value is not None
        ]
        if normalized_statuses:
            placeholders = ', '.join(['%s'] * len(normalized_statuses))
            query += f" AND COALESCE(TRIM(UPPER(a.assstatus::text)), '') IN ({placeholders})"
            params.extend(normalized_statuses)

        situations = filters.get('situations') or []
        normalized_situations = [
            normalize_lookup_code(value) for value in situations if value is not None
        ]
        if normalized_situations:
            placeholders = ', '.join(['%s'] * len(normalized_situations))
            query += f" AND COALESCE(TRIM(UPPER(a.asssitua::text)), '') IN ({placeholders})"
            params.extend(normalized_situations)

        load_lot_codes = [
            (value or '').strip() for value in (filters.get('load_lots') or []) if value is not None
        ]
        load_lot_codes = [code for code in load_lot_codes if code]
        if load_lot_codes:
            placeholders = ', '.join(['%s'] * len(load_lot_codes))
            query += f" AND COALESCE(TRIM(CAST(a.asslcacod AS TEXT)), '') IN ({placeholders})"
            params.extend(load_lot_codes)

        production_lot_codes = [
            (value or '').strip()
            for value in (filters.get('production_lots') or [])
            if value is not None
        ]
        production_lot_codes = [code for code in production_lot_codes if code]
        if production_lot_codes:
            placeholders = ', '.join(['%s'] * len(production_lot_codes))
            query += f"""
                AND EXISTS (
                    SELECT 1
                    FROM acaorde4 apl
                    JOIN ordem o ON o.ordem = apl.acaoorde
                    WHERE TRIM(CAST(apl.acaorasco AS TEXT)) = TRIM(CAST(a.assistec AS TEXT))
                      AND COALESCE(TRIM(CAST(o.lotcod AS TEXT)), '') IN ({placeholders})
                )
            """
            params.extend(production_lot_codes)

        line_filters = [
            (value or '').strip().upper()
            for value in (filters.get('lines') or [])
            if value is not None
        ]
        line_filters = [value for value in line_filters if value]
        if line_filters:
            placeholders = ', '.join(['%s'] * len(line_filters))
            query += f" AND COALESCE(li.linha, '') IN ({placeholders})"
            params.extend(line_filters)

        code_filter = (filters.get('assistance_code') or '').strip()
        if code_filter:
            query += " AND CAST(a.assistec AS TEXT) ILIKE %s"
            params.append(f"%{code_filter}%")

        customer_filter = (filters.get('customer') or '').strip()
        if customer_filter:
            like_pattern = f"%{customer_filter}%"
            query += """
                AND (
                    COALESCE(e.empnome, '') ILIKE %s
                    OR COALESCE(CAST(a.asscliente AS TEXT), '') ILIKE %s
                )
            """
            params.extend([like_pattern, like_pattern])

        representative_filter = (filters.get('representative') or '').strip()
        if representative_filter:
            like_pattern = f"%{representative_filter}%"
            query += """
                AND (
                    COALESCE(v.vennome, '') ILIKE %s
                    OR COALESCE(CAST(a.assrepres AS TEXT), '') ILIKE %s
                )
            """
            params.extend([like_pattern, like_pattern])

        responsavel_filter = (filters.get('responsavel') or '').strip()
        if responsavel_filter:
            like_pattern = f"%{responsavel_filter}%"
            query += """
                AND COALESCE(resp.responsavel_nome, '') ILIKE %s
            """
            params.append(like_pattern)

        query += """
            GROUP BY
                a.assistec,
                a.asscliente,
                e.empnome,
                cid.cidnome,
                cid.estado,
                a.assrepres,
                v.vennome,
                a.assdata,
                a.assstatus,
                a.asssitua,
                a.assobs1,
                a.assnurep,
                a.asstipo,
                a.assdtalt,
                a.asshralt,
                a.assusualt,
                resp.responsavel_nome,
                pt.reservado,
                pt.separado,
                pt.carregado,
                li.linha
        """

        sort_by = filters.get('sort_by', 'assdata')
        sort_order = filters.get('sort_order', 'desc')
        sort_column_map = {
            'assistec': 'a.assistec',
            'assdata': 'a.assdata',
            'cliente_nome': 'cliente_nome',
            'cidade_estado': 'cidade_nome',
            'representante_nome': 'representante_nome',
            'responsavel_nome': 'responsavel_nome',
            'status_label': 'a.assstatus',
            'situacao_label': 'a.asssitua',
            'quantidade_pecas': 'quantidade_pecas',
            'valor_total': 'valor_total',
            'ultima_alteracao_display': 'a.assdtalt',
            'reservado': 'reservado',
            'separado': 'separado',
            'carregado': 'carregado',
            'linha': 'linha'
        }
        sort_column = sort_column_map.get(sort_by, 'a.assdata')
        sort_direction = 'ASC' if sort_order == 'asc' else 'DESC'

        query += f" ORDER BY {sort_column} {sort_direction}, a.assistec DESC"

        cur.execute(query, tuple(params))
        column_names = [desc[0] for desc in cur.description]

        for row in cur.fetchall():
            record = dict(zip(column_names, row))
            record['status_label'] = get_technical_assistance_status_label(record.get('assstatus'))
            record['situacao_label'] = get_technical_assistance_situation_label(record.get('asssitua'))
            record['responsavel_nome'] = (record.get('responsavel_nome') or '').strip()

            try:
                record['quantidade_pecas'] = Decimal(record.get('quantidade_pecas') or 0)
            except (TypeError, InvalidOperation):
                record['quantidade_pecas'] = Decimal('0')

            try:
                record['valor_total'] = Decimal(record.get('valor_total') or 0)
            except (TypeError, InvalidOperation):
                record['valor_total'] = Decimal('0')

            total_itens_raw = record.get('total_itens') or 0
            try:
                record['total_itens'] = int(total_itens_raw)
            except (TypeError, ValueError):
                record['total_itens'] = 0

            ultima_data = record.get('assdtalt')
            ultima_hora = (record.get('asshralt') or '').strip()
            if ultima_data and ultima_hora:
                record['ultima_alteracao_display'] = f"{ultima_data.strftime('%d/%m/%Y')} {ultima_hora}"
            elif ultima_data:
                record['ultima_alteracao_display'] = ultima_data.strftime('%d/%m/%Y')
            else:
                record['ultima_alteracao_display'] = ''

            cidade = (record.get('cidade_nome') or '').strip()
            estado = (record.get('estado_sigla') or '').strip()
            if cidade and estado:
                record['cidade_estado'] = f"{cidade}/{estado}"
            else:
                record['cidade_estado'] = cidade or estado

            # Processar valores de reservado, separado e carregado
            try:
                record['reservado'] = Decimal(record.get('reservado') or 0)
            except (TypeError, InvalidOperation):
                record['reservado'] = Decimal('0')

            try:
                record['separado'] = Decimal(record.get('separado') or 0)
            except (TypeError, InvalidOperation):
                record['separado'] = Decimal('0')

            try:
                record['carregado'] = Decimal(record.get('carregado') or 0)
            except (TypeError, InvalidOperation):
                record['carregado'] = Decimal('0')

            record['kpi_status'] = calculate_order_kpi(
                record.get('reservado'),
                record.get('separado'),
                record.get('carregado'),
            )

            # Processar linha
            record['linha'] = (record.get('linha') or '').strip()

            records.append(record)
    except UndefinedColumn as error:
        error_message = f"Colunas necessárias para assistência técnica não foram encontradas: {error}"
    except (Exception, Error) as error:
        error_message = f"Erro ao buscar assistências técnicas: {error}"
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return records, error_message


def get_assistance_header_data(conn, code_value):
    """
    Recupera o cabeçalho compartilhado das assistências.
    """
    header_cur = None
    lot_cur = None
    try:
        header_cur = conn.cursor()
        header_cur.execute(
            """
            SELECT
                CAST(a.assistec AS TEXT) AS assistencia,
                COALESCE(e.empnome, '') AS cliente_nome,
                COALESCE(cid.cidnome, '') AS cidade_nome,
                COALESCE(cid.estado, '') AS estado_sigla,
                a.assdtalt,
                COALESCE(a.asslcacod::text, '') AS lote_carga_codigo,
                COALESCE(lc.lcades, '') AS lote_carga_descricao
            FROM assistec a
            LEFT JOIN empresa e ON e.empresa = a.asscliente
            LEFT JOIN cidade cid ON cid.cidade = e.empcidade
            LEFT JOIN lotecar lc ON lc.lcacod = a.asslcacod
            WHERE CAST(a.assistec AS TEXT) = %s
            """,
            (code_value,),
        )
        header_row = header_cur.fetchone()
        if not header_row:
            return None, {'message': 'Assistência não encontrada.', 'status': 404}

        (
            assistance_id,
            cliente_nome,
            cidade_nome,
            estado_sigla,
            data_atualizacao,
            lote_carga_codigo,
            lote_carga_descricao,
        ) = header_row

        data_pedido_display = ''
        if isinstance(data_atualizacao, (datetime.date, datetime.datetime)):
            data_pedido_display = data_atualizacao.strftime('%d/%m/%Y')
        elif data_atualizacao:
            data_pedido_display = str(data_atualizacao)

        lote_carga_codigo = (lote_carga_codigo or '').strip()
        lote_carga_descricao = (lote_carga_descricao or '').strip()

        lote_carga_display = ''
        if lote_carga_codigo:
            lote_carga_display = lote_carga_codigo
            if lote_carga_descricao:
                lote_carga_display = f"{lote_carga_display} - {lote_carga_descricao}"
        elif lote_carga_descricao:
            lote_carga_display = lote_carga_descricao

        lote_producao_display = ''
        lot_cur = conn.cursor()
        lot_cur.execute(
            """
            WITH production_lots AS (
                SELECT DISTINCT
                    COALESCE(lp.lotcod::text, '') AS lotcod,
                    COALESCE(lp.lotdes, '') AS lotdes
                FROM acaorde4 ao
                JOIN ordem o ON o.ordem = ao.acaoorde
                LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
                WHERE CAST(ao.acaorasco AS TEXT) = %s
            )
            SELECT lotcod, lotdes
            FROM production_lots
            ORDER BY lotcod
            """,
            (code_value,),
        )
        production_rows = lot_cur.fetchall()

        production_lots = []
        for lotcod, lotdes in production_rows:
            code = (lotcod or '').strip()
            description = (lotdes or '').strip()
            if code and description:
                production_lots.append(f"{code} - {description}")
            elif code:
                production_lots.append(code)
            elif description:
                production_lots.append(description)
        if production_lots:
            lote_producao_display = '; '.join(production_lots)

        header_data = {
            'assistencia': (assistance_id or '').strip(),
            'cliente': (cliente_nome or '').strip(),
            'cidade': (cidade_nome or '').strip(),
            'uf': (estado_sigla or '').strip(),
            'data_pedido': data_pedido_display,
            'lote_producao': lote_producao_display,
            'lote_carga': lote_carga_display,
        }

        return header_data, None
    except (Exception, Error) as error:
        return None, {'message': f'Erro ao carregar cabeçalho da assistência: {error}', 'status': 500}
    finally:
        if header_cur:
            header_cur.close()
        if lot_cur:
            lot_cur.close()


def fetch_technical_assistance_details(assistance_code):
    """
    Recupera os detalhes (cabeçalho e itens) de uma assistência técnica específica.
    """
    code_value = str(assistance_code or '').strip()
    if not code_value:
        return None, {'message': 'Assistência inválida.', 'status': 400}

    conn = get_erp_db_connection()
    if not conn:
        return None, {'message': 'Não foi possível conectar ao banco de dados do ERP.', 'status': 500}

    items = []

    try:
        header_data, header_error = get_assistance_header_data(conn, code_value)
        if header_error:
            return None, header_error

        items_cur = conn.cursor()
        items_cur.execute(
            """
            SELECT
                COALESCE(TRIM(i.aspproduto::text), '') AS codigo_produto,
                COALESCE(TRIM(i.aspseq::text), '') AS sequencia,
                COALESCE(prod.pronome::text, '') AS produto_nome,
                COALESCE(i.aspquanti, 0) AS quantidade,
                COALESCE(i.aspvalor, 0) AS valor_unitario,
                COALESCE(i.asptotal, 0) AS valor_total
            FROM assiste1 i
            LEFT JOIN produto prod ON prod.produto = i.aspproduto
            WHERE CAST(i.assistec AS TEXT) = %s
            ORDER BY
                CASE
                    WHEN TRIM(i.aspseq::text) ~ '^[0-9]+$' THEN LPAD(TRIM(i.aspseq::text), 10, '0')
                    ELSE TRIM(i.aspseq::text)
                END,
                COALESCE(TRIM(i.aspproduto::text), '')
            """,
            (code_value,),
        )
        item_rows = items_cur.fetchall()
        items_cur.close()

        total_quantidade = Decimal('0')
        total_valor = Decimal('0')
        for (
            codigo_produto,
            sequencia,
            produto_nome,
            quantidade,
            valor_unitario,
            valor_total,
        ) in item_rows:
            try:
                quantidade_dec = Decimal(str(quantidade or 0))
            except (TypeError, InvalidOperation, ValueError):
                quantidade_dec = Decimal('0')
            try:
                valor_unitario_dec = Decimal(str(valor_unitario or 0))
            except (TypeError, InvalidOperation, ValueError):
                valor_unitario_dec = Decimal('0')
            try:
                valor_total_dec = Decimal(str(valor_total or 0))
            except (TypeError, InvalidOperation, ValueError):
                valor_total_dec = Decimal('0')

            items.append(
                {
                    'codigo_produto': codigo_produto,
                    'sequencia': sequencia,
                    'produto': produto_nome,
                    'quantidade': float(quantidade_dec),
                    'valor_unitario': float(valor_unitario_dec),
                    'valor_total': float(valor_total_dec),
                }
            )

            total_quantidade += quantidade_dec
            total_valor += valor_total_dec

        totals_payload = {
            'quantidade_total': float(total_quantidade),
            'valor_total': float(total_valor),
        }

        return {'header': header_data, 'items': items, 'totals': totals_payload}, None
    except (Exception, Error) as error:
        return None, {'message': f'Erro ao carregar detalhes da assistência: {error}', 'status': 500}
    finally:
        if conn:
            conn.close()


def fetch_production_assistance_details(assistance_code):
    """
    Recupera os detalhes da tela Consultar Assistências utilizando os movimentos do projmovi.
    """
    code_value = str(assistance_code or '').strip()
    if not code_value:
        return None, {'message': 'Assistência inválida.', 'status': 400}

    conn = get_erp_db_connection()
    if not conn:
        return None, {'message': 'Não foi possível conectar ao banco de dados do ERP.', 'status': 500}

    column_check_cursor = None
    assistance_items_cur = None
    movement_cur = None

    try:
        header_data, header_error = get_assistance_header_data(conn, code_value)
        if header_error:
            return None, header_error

        try:
            column_check_cursor = conn.cursor()
            column_check_cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'projmovi'
                """
            )
            projmovi_columns = {
                (row[0] or '').lower()
                for row in column_check_cursor.fetchall()
                if row and row[0]
            }
        except Error as error:
            print(f"Erro ao verificar colunas da tabela 'projmovi' (assistência): {error}")
            projmovi_columns = None
        finally:
            if column_check_cursor:
                column_check_cursor.close()
                column_check_cursor = None

        has_prjmproex_column = projmovi_columns is None or 'prjmproex' in projmovi_columns
        has_prjmpedse_column = projmovi_columns is None or 'prjmpedse' in projmovi_columns
        has_prjmseque_column = projmovi_columns is None or 'prjmseque' in projmovi_columns
        has_prjmprodu_column = projmovi_columns is None or 'prjmprodu' in projmovi_columns

        assistance_items_cur = conn.cursor()
        assistance_items_cur.execute(
            """
            SELECT
                COALESCE(TRIM(i.aspproduto::text), '') AS codigo_produto,
                COALESCE(TRIM(i.aspseq::text), '') AS sequencia,
                COALESCE(prod.pronome::text, '') AS produto_nome
            FROM assiste1 i
            LEFT JOIN produto prod ON prod.produto = i.aspproduto
            WHERE CAST(i.assistec AS TEXT) = %s
            ORDER BY
                CASE
                    WHEN NULLIF(TRIM(i.aspseq::text), '') ~ '^[0-9]+$' THEN LPAD(TRIM(i.aspseq::text), 10, '0')
                    ELSE TRIM(i.aspseq::text)
                END,
                COALESCE(TRIM(i.aspproduto::text), '')
            """,
            (code_value,),
        )
        assistance_rows = assistance_items_cur.fetchall()
        assistance_items_cur.close()
        assistance_items_cur = None

        product_code_source = None
        if has_prjmproex_column:
            codigo_produto_expr = "COALESCE(TRIM(pm.prjmproex::text), '')"
            product_code_source = "pm.prjmproex"
        elif has_prjmprodu_column:
            codigo_produto_expr = "COALESCE(TRIM(pm.prjmprodu::text), '')"
            product_code_source = "pm.prjmprodu"
        else:
            codigo_produto_expr = "''"

        if has_prjmpedse_column:
            sequencia_expr = "COALESCE(TRIM(pm.prjmpedse::text), '')"
        elif has_prjmseque_column:
            sequencia_expr = "COALESCE(TRIM(pm.prjmseque::text), '')"
        else:
            sequencia_expr = "''"

        if product_code_source:
            produto_join = f"""
                LEFT JOIN produto prod
                    ON COALESCE(TRIM(prod.produto::text), '') = COALESCE(TRIM({product_code_source}::text), '')
            """
            produto_nome_expr = "COALESCE(prod.pronome::text, '')"
        else:
            produto_join = ""
            produto_nome_expr = "''"

        sequence_sort_expr = (
            f"CASE WHEN NULLIF({sequencia_expr}, '') ~ '^[0-9]+$' THEN "
            f"LPAD({sequencia_expr}, 10, '0') ELSE {sequencia_expr} END"
        )

        movement_cur = conn.cursor()
        movement_query = f"""
            SELECT
                {codigo_produto_expr} AS codigo_produto,
                {sequencia_expr} AS sequencia,
                {produto_nome_expr} AS produto_nome,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'R'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS reservado,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'P'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS separado,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'C'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS carregado
            FROM projmovi pm
            {produto_join}
            WHERE CAST(pm.prjmpedid AS TEXT) = %s
            GROUP BY codigo_produto, sequencia, produto_nome
            ORDER BY {sequence_sort_expr}, codigo_produto
        """
        movement_cur.execute(movement_query, (code_value,))
        movement_rows = movement_cur.fetchall()
        movement_cur.close()
        movement_cur = None

        def safe_decimal(value):
            try:
                return Decimal(str(value or 0))
            except (TypeError, InvalidOperation, ValueError):
                return Decimal('0')

        movement_map = {}
        for (
            movimento_codigo,
            movimento_sequencia,
            movimento_produto_nome,
            reservado_raw,
            separado_raw,
            carregado_raw,
        ) in movement_rows:
            normalized_code = (movimento_codigo or '').strip()
            normalized_seq = (movimento_sequencia or '').strip()
            movement_map[(normalized_code, normalized_seq)] = {
                'reservado': safe_decimal(reservado_raw),
                'separado': safe_decimal(separado_raw),
                'carregado': safe_decimal(carregado_raw),
                'produto': (movimento_produto_nome or '').strip(),
            }

        total_reservado = Decimal('0')
        total_separado = Decimal('0')
        total_carregado = Decimal('0')
        items = []
        for (codigo_produto, sequencia, produto_nome) in assistance_rows:
            normalized_code = (codigo_produto or '').strip()
            normalized_seq = (sequencia or '').strip()
            movement = movement_map.get((normalized_code, normalized_seq))
            if movement is None and normalized_code:
                movement = movement_map.get((normalized_code, ''))

            reservado = movement['reservado'] if movement else Decimal('0')
            separado = movement['separado'] if movement else Decimal('0')
            carregado = movement['carregado'] if movement else Decimal('0')

            items.append(
                {
                    'codigo_produto': normalized_code,
                    'sequencia': normalized_seq,
                    'produto': (produto_nome or '').strip(),
                    'reservado': float(reservado),
                    'separado': float(separado),
                    'carregado': float(carregado),
                }
            )

            total_reservado += reservado
            total_separado += separado
            total_carregado += carregado

        totals_payload = {
            'reservado_total': float(total_reservado),
            'separado_total': float(total_separado),
            'carregado_total': float(total_carregado),
        }

        return {'header': header_data, 'items': items, 'totals': totals_payload}, None
    except (Exception, Error) as error:
        return None, {'message': f'Erro ao carregar detalhes da assistência: {error}', 'status': 500}
    finally:
        if movement_cur:
            movement_cur.close()
        if assistance_items_cur:
            assistance_items_cur.close()
        if conn:
            conn.close()


def get_technical_assistance_status_options():
    """Retorna a lista de status disponíveis para assistências técnicas."""
    options = []
    conn = get_erp_db_connection()
    if not conn:
        return options

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT DISTINCT COALESCE(TRIM(a.assstatus::text), '')
            FROM assistec a
            ORDER BY 1
            """
        )
        seen = set()
        for (raw_code,) in cur.fetchall():
            normalized = normalize_lookup_code(raw_code)
            if normalized in seen:
                continue
            seen.add(normalized)
            options.append(
                {
                    'code': normalized,
                    'label': get_technical_assistance_status_label(normalized),
                }
            )
    except UndefinedColumn:
        pass
    except (Exception, Error) as error:
        print(f"Erro ao buscar status de assistência técnica: {error}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if not options:
        seen = set()
        for code, label in TECHNICAL_ASSISTANCE_STATUS_LABELS.items():
            normalized = normalize_lookup_code(code)
            if normalized in seen:
                continue
            seen.add(normalized)
            options.append({'code': normalized, 'label': label})

    options.sort(key=lambda item: item['label'])
    return options


def get_technical_assistance_situation_options():
    """Retorna a lista de situações disponíveis para assistências técnicas."""
    options = []
    conn = get_erp_db_connection()
    if not conn:
        return options

    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT DISTINCT COALESCE(TRIM(a.asssitua::text), '')
            FROM assistec a
            ORDER BY 1
            """
        )
        seen = set()
        for (raw_code,) in cur.fetchall():
            normalized = normalize_lookup_code(raw_code)
            if normalized in seen:
                continue
            seen.add(normalized)
            options.append(
                {
                    'code': normalized,
                    'label': get_technical_assistance_situation_label(normalized),
                }
            )
    except UndefinedColumn:
        pass
    except (Exception, Error) as error:
        print(f"Erro ao buscar situações de assistência técnica: {error}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if not options:
        seen = set()
        for code, label in TECHNICAL_ASSISTANCE_SITUATION_LABELS.items():
            normalized = normalize_lookup_code(code)
            if normalized in seen:
                continue
            seen.add(normalized)
            options.append({'code': normalized, 'label': label})

    options.sort(key=lambda item: item['label'])
    return options


def get_order_header_data(conn, pedido_value):
    """
    Shared helper that retrieves the header information for order detail pop-ups.
    Returns (header_dict, error_dict).
    """
    has_lcapecod_column = False
    column_check_cursor = None

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'pedido'
                  AND column_name = 'lcapecod'
            )
            """
        )
        result = column_check_cursor.fetchone()
        if result:
            has_lcapecod_column = bool(result[0])
    except Error as e:
        print(f"Erro ao verificar a coluna 'lcapecod' na tabela 'pedido' (detalhes): {e}")
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    cur = None
    load_lot_select = (
        "CAST(p.lcapecod AS TEXT) AS load_lot_code,\n                COALESCE(lc.lcades, '') AS load_lot_description"
        if has_lcapecod_column
        else "NULL AS load_lot_code,\n                '' AS load_lot_description"
    )
    load_lot_join = "LEFT JOIN lotecar lc ON p.lcapecod = lc.lcacod" if has_lcapecod_column else ""
    header_query = f"""
        WITH production_lots AS (
            SELECT
                CAST(lots.pedido AS TEXT) AS pedido,
                STRING_AGG(lots.lot_display, '; ' ORDER BY lots.lot_display) AS production_lots_display
            FROM (
                SELECT DISTINCT
                    ao.acaopedi AS pedido,
                    CASE
                        WHEN COALESCE(lp.lotcod::text, '') <> '' THEN
                            lp.lotcod::text ||
                            CASE
                                WHEN COALESCE(lp.lotdes, '') <> '' THEN ' - ' || lp.lotdes
                                ELSE ''
                            END
                        ELSE ''
                    END AS lot_display
                FROM acaorde2 ao
                JOIN ordem o ON o.ordem = ao.acaoorde
                LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
                WHERE CAST(ao.acaopedi AS TEXT) = %s
            ) lots
            WHERE lots.lot_display <> ''
            GROUP BY lots.pedido
        )
        SELECT
            CAST(p.pedido AS TEXT) AS pedido,
            p.peddata,
            COALESCE(e.empnome, '') AS cliente,
            CASE
                WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome
                WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text
                ELSE ''
            END AS cidade,
            CASE
                WHEN COALESCE(c.estado, '') <> '' THEN c.estado
                WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text
                ELSE ''
            END AS estado,
            COALESCE(pl.production_lots_display, '') AS production_lots_display,
            {load_lot_select},
            COALESCE(rc.rgcdes, '') AS regcar_description
        FROM pedido p
        LEFT JOIN empresa e ON p.pedcliente = e.empresa
        LEFT JOIN cidade c ON p.pedentcid = c.cidade
        LEFT JOIN regcar rc ON c.rgccicod = rc.rgccod
        LEFT JOIN production_lots pl ON pl.pedido = CAST(p.pedido AS TEXT)
        {load_lot_join}
        WHERE CAST(p.pedido AS TEXT) = %s
    """

    try:
        cur = conn.cursor()
        cur.execute(header_query, (pedido_value, pedido_value))
        header_row = cur.fetchone()
    except Error as e:
        print(f"Erro ao carregar cabeçalho do pedido {pedido_value}: {e}")
        return None, {'message': 'Erro ao carregar detalhes do pedido.', 'status': 500}
    finally:
        if cur:
            cur.close()

    if not header_row:
        return None, {'message': 'Pedido não encontrado.', 'status': 404}

    (
        pedido,
        peddata,
        cliente,
        cidade,
        estado,
        production_lots_display,
        load_lot_code,
        load_lot_description,
        regcar_description,
    ) = header_row

    header_data = {
        'pedido': pedido or '',
        'cliente': cliente or '',
        'cidade': cidade or '',
        'uf': estado or '',
        'data_pedido': '',
        'lote_producao': production_lots_display or '',
        'lote_carga': '',
        'regcar_description': regcar_description or '',
    }

    if isinstance(peddata, (datetime.date, datetime.datetime)):
        header_data['data_pedido'] = peddata.strftime('%d/%m/%Y')
    elif peddata:
        header_data['data_pedido'] = str(peddata)

    if load_lot_code:
        load_lot_str = str(load_lot_code)
        if load_lot_description:
            load_lot_str = f"{load_lot_str} - {load_lot_description}"
        header_data['lote_carga'] = load_lot_str

    return header_data, None


def fetch_order_details(pedido_code):
    """
    Recupera os detalhes de um pedido específico (cabeçalho e itens) a partir do ERP.
    Retorna uma tupla (dados, erro), em que erro é um dicionário com 'message' e 'status'.
    """
    pedido_value = (pedido_code or '').strip()
    if not pedido_value:
        return None, {'message': 'Pedido inválido.', 'status': 400}

    conn = get_erp_db_connection()
    if not conn:
        return None, {'message': 'Não foi possível conectar ao banco de dados do ERP.', 'status': 500}

    column_check_cursor = None

    header_data, header_error = get_order_header_data(conn, pedido_value)
    if header_error:
        if conn:
            conn.close()
        return None, header_error

    regcar_data = parse_regcar_description(header_data.get('regcar_description', ''))
    header_data.pop('regcar_description', None)

    details = {'header': header_data, 'items': []}

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'pedprodu'
            """
        )
        pedprodu_columns = {
            (row[0] or '').lower()
            for row in column_check_cursor.fetchall()
            if row and row[0]
        }
    except Error as e:
        print(f"Erro ao verificar colunas da tabela 'pedprodu': {e}")
        pedprodu_columns = None
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    column_check_cursor = None
    projmovi_columns = None
    has_prjmproex_column = False
    has_prjmseque_column = False

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'projmovi'
            """
        )
        projmovi_columns = {
            (row[0] or '').lower()
            for row in column_check_cursor.fetchall()
            if row and row[0]
        }
        has_prjmproex_column = 'prjmproex' in projmovi_columns if projmovi_columns is not None else False
        has_prjmseque_column = 'prjmseque' in projmovi_columns if projmovi_columns is not None else False
    except Error as e:
        print(f"Erro ao verificar colunas da tabela 'projmovi': {e}")
        projmovi_columns = None
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    if projmovi_columns is not None and 'prjmproex' not in projmovi_columns:
        print(
            "Coluna opcional 'prjmproex' ausente em 'projmovi'. "
            "Usando o código do produto da tabela 'pedprodu'."
        )

    def build_items_aggregate(column_name, expression, alias):
        column_key = (column_name or '').lower()
        if pedprodu_columns is None or column_key in pedprodu_columns:
            return expression
        print(
            f"Coluna opcional '{column_name}' ausente em 'pedprodu'. "
            f"Usando valor padrão para '{alias}'."
        )
        return f"0 AS {alias}"

    try:
        items_cur = conn.cursor()
        quantidade_total_expr = build_items_aggregate(
            'pprquanti',
            "SUM(COALESCE(pp.pprquanti, 0)) AS quantidade_total",
            'quantidade_total',
        )
        valor_tabela_expr = build_items_aggregate(
            'pprlista',
            "SUM(COALESCE(pp.pprlista, 0)) AS valor_tabela",
            'valor_tabela',
        )
        percentual_desconto_expr = build_items_aggregate(
            'pprdesc1',
            "AVG(COALESCE(pp.pprdesc1, 0)) AS percentual_desconto",
            'percentual_desconto',
        )
        valor_unitario_expr = build_items_aggregate(
            'pprvalor',
            "SUM(COALESCE(pp.pprvalor, 0)) AS valor_unitario_total",
            'valor_unitario_total',
        )
        valor_ipi_expr = build_items_aggregate(
            'pprvlipi',
            "SUM(COALESCE(pp.pprvlipi, 0)) AS valor_ipi",
            'valor_ipi',
        )
        valor_bruto_expr = build_items_aggregate(
            'pprvlsoma',
            "SUM(COALESCE(pp.pprvlsoma, 0)) AS valor_bruto_total",
            'valor_bruto_total',
        )
        desconto_pedido_expr = build_items_aggregate(
            'pprdescped',
            "SUM(COALESCE(pp.pprdescped, 0)) AS desconto_pedido_total",
            'desconto_pedido_total',
        )

        produto_expr = "COALESCE(pp.pprproduto::text, '')"
        sequencia_expr = "COALESCE(pp.pprseq::text, '')"
        if has_prjmproex_column:
            if has_prjmseque_column:
                projmovi_join = f"""
            LEFT JOIN (
                SELECT
                    CAST(prjmpedid AS TEXT) AS pedido,
                    COALESCE(prjmseque::text, '') AS sequencia,
                    MAX(COALESCE(prjmproex::text, '')) AS codigo_produto_externo
                FROM projmovi
                WHERE prjmpedid IS NOT NULL
                GROUP BY CAST(prjmpedid AS TEXT), COALESCE(prjmseque::text, '')
            ) pm ON pm.pedido = CAST(pp.pedido AS TEXT) AND pm.sequencia = {sequencia_expr}
                """
            else:
                projmovi_join = f"""
            LEFT JOIN (
                SELECT
                    CAST(prjmpedid AS TEXT) AS pedido,
                    COALESCE(prjmproex::text, '') AS produto_codigo,
                    MAX(COALESCE(prjmproex::text, '')) AS codigo_produto_externo
                FROM projmovi
                WHERE prjmpedid IS NOT NULL
                GROUP BY CAST(prjmpedid AS TEXT), COALESCE(prjmproex::text, '')
            ) pm ON pm.pedido = CAST(pp.pedido AS TEXT) AND pm.produto_codigo = {produto_expr}
                """
            codigo_produto_select = f"""
                COALESCE(
                    NULLIF(MAX(pm.codigo_produto_externo), ''),
                    {produto_expr}
                ) AS codigo_produto
            """
        else:
            projmovi_join = ""
            codigo_produto_select = f"{produto_expr} AS codigo_produto"
        items_query = f"""
            SELECT
                {codigo_produto_select},
                {sequencia_expr} AS sequencia,
                COALESCE(prod.pronome::text, '') AS produto_nome,
                COALESCE(g.grunome::text, '') AS grupo_nome,
                {quantidade_total_expr},
                {valor_tabela_expr},
                {percentual_desconto_expr},
                {valor_unitario_expr},
                {valor_ipi_expr},
                {valor_bruto_expr},
                {desconto_pedido_expr}
            FROM pedprodu pp
            LEFT JOIN produto prod ON prod.produto = pp.pprproduto
            LEFT JOIN grupo g ON g.grupo = prod.grupo
            {projmovi_join}
            WHERE CAST(pp.pedido AS TEXT) = %s
            GROUP BY pp.pprproduto, pp.pprseq, prod.pronome, g.grunome
            ORDER BY pp.pprseq, pp.pprproduto
            """

        items_cur.execute(items_query, (pedido_value,))
        item_rows = items_cur.fetchall()
        items_cur.close()

        for item_row in item_rows:
            (
                codigo_produto,
                sequencia,
                produto_nome,
                grupo_nome,
                quantidade_total_raw,
                valor_tabela_raw,
                percentual_desc_raw,
                valor_unitario_raw,
                valor_ipi_raw,
                valor_bruto_raw,
                desconto_pedido_raw,
            ) = item_row

            try:
                quantidade_total = float(quantidade_total_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                quantidade_total = 0.0

            try:
                valor_tabela = float(valor_tabela_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_tabela = 0.0

            try:
                percentual_desc = float(percentual_desc_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                percentual_desc = 0.0

            try:
                valor_unitario_total = float(valor_unitario_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_unitario_total = 0.0

            try:
                valor_ipi = float(valor_ipi_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_ipi = 0.0

            try:
                valor_bruto = float(valor_bruto_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_bruto = 0.0

            try:
                desconto_pedido = float(desconto_pedido_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                desconto_pedido = 0.0

            valor_total = valor_bruto - desconto_pedido

            product_line = get_product_line(grupo_nome)
            product_ref = (produto_nome or '').strip()[:2]
            freight_pct_fraction = calculate_freight_percentage(
                product_line, product_ref, regcar_data
            )
            freight_pct_display = freight_pct_fraction * 100.0
            valor_frete = valor_total * freight_pct_fraction

            details['items'].append(
                {
                    'codigo_produto': codigo_produto,
                    'sequencia': sequencia,
                    'produto': produto_nome,
                    'quantidade_total': quantidade_total,
                    'valor_tabela': valor_tabela,
                    'percentual_desconto': percentual_desc,
                    'valor_unitario_total': valor_unitario_total,
                    'valor_ipi': valor_ipi,
                    'percentual_frete': freight_pct_display,
                    'valor_frete': valor_frete,
                    'valor_total': valor_total,
                }
            )

        return details, None
    except Error as e:
        print(f"Erro ao carregar detalhes do pedido {pedido_value}: {e}")
        return None, {'message': 'Erro ao carregar detalhes do pedido.', 'status': 500}
    finally:
        if conn:
            conn.close()


def fetch_logistics_order_details(pedido_code):
    """
    Recupera os detalhes logísticos (movimentação de reserva/separação/carga) de um pedido.
    """
    pedido_value = (pedido_code or '').strip()
    if not pedido_value:
        return None, {'message': 'Pedido inválido.', 'status': 400}

    conn = get_erp_db_connection()
    if not conn:
        return None, {'message': 'Não foi possível conectar ao banco de dados do ERP.', 'status': 500}

    header_data, header_error = get_order_header_data(conn, pedido_value)
    if header_error:
        if conn:
            conn.close()
        return None, header_error

    details = {'header': header_data, 'items': []}
    header_data.pop('regcar_description', None)

    column_check_cursor = None
    projmovi_columns = None
    has_prjmproex_column = False
    has_prjmpedse_column = False
    has_prjmseque_column = False
    has_prjmprodu_column = False

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'projmovi'
            """
        )
        projmovi_columns = {
            (row[0] or '').lower()
            for row in column_check_cursor.fetchall()
            if row and row[0]
        }
        if projmovi_columns is not None:
            has_prjmproex_column = 'prjmproex' in projmovi_columns
            has_prjmpedse_column = 'prjmpedse' in projmovi_columns
            has_prjmseque_column = 'prjmseque' in projmovi_columns
            has_prjmprodu_column = 'prjmprodu' in projmovi_columns
    except Error as e:
        print(f"Erro ao verificar colunas da tabela 'projmovi' (detalhes logísticos): {e}")
        projmovi_columns = None
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    codigo_produto_expr = (
        "COALESCE(pm.prjmproex::text, '')"
        if has_prjmproex_column
        else "COALESCE(pp.pprproduto::text, '')"
    )
    if has_prjmpedse_column:
        sequencia_expr = "COALESCE(pm.prjmpedse::text, '')"
    elif has_prjmseque_column:
        sequencia_expr = "COALESCE(pm.prjmseque::text, '')"
    else:
        sequencia_expr = "COALESCE(pp.pprseq::text, '')"

    pedprodu_join_conditions = ["CAST(pp.pedido AS TEXT) = CAST(pm.prjmpedid AS TEXT)"]
    if has_prjmpedse_column:
        pedprodu_join_conditions.append("COALESCE(pp.pprseq::text, '') = COALESCE(pm.prjmpedse::text, '')")
    elif has_prjmseque_column:
        pedprodu_join_conditions.append("COALESCE(pp.pprseq::text, '') = COALESCE(pm.prjmseque::text, '')")
    if has_prjmprodu_column:
        pedprodu_join_conditions.append("COALESCE(pp.pprproduto::text, '') = COALESCE(pm.prjmprodu::text, '')")

    pedprodu_join = f"""
        LEFT JOIN pedprodu pp ON {' AND '.join(pedprodu_join_conditions)}
    """

    sequence_sort_expr = (
        f"CASE WHEN NULLIF({sequencia_expr}, '') ~ '^[0-9]+$' THEN "
        f"LPAD({sequencia_expr}, 10, '0') ELSE {sequencia_expr} END"
    )

    try:
        items_cur = conn.cursor()
        items_query = f"""
            SELECT
                {codigo_produto_expr} AS codigo_produto,
                {sequencia_expr} AS sequencia,
                COALESCE(prod.pronome::text, '') AS produto_nome,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'R'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS reservado,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'P'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS separado,
                SUM(
                    CASE WHEN UPPER(COALESCE(pm.prjmovtip, '')) = 'C'
                        THEN COALESCE(pm.prjmquant, 0) ELSE 0 END
                ) AS carregado
            FROM projmovi pm
            {pedprodu_join}
            LEFT JOIN produto prod ON prod.produto = pp.pprproduto
            WHERE CAST(pm.prjmpedid AS TEXT) = %s
            GROUP BY codigo_produto, sequencia, produto_nome
            ORDER BY {sequence_sort_expr}, codigo_produto
        """
        items_cur.execute(items_query, (pedido_value,))
        item_rows = items_cur.fetchall()
        items_cur.close()

        for row in item_rows:
            (
                codigo_produto,
                sequencia,
                produto_nome,
                reservado_raw,
                separado_raw,
                carregado_raw,
            ) = row

            try:
                reservado = float(reservado_raw or 0)
            except (TypeError, ValueError):
                reservado = 0.0

            try:
                separado = float(separado_raw or 0)
            except (TypeError, ValueError):
                separado = 0.0

            try:
                carregado = float(carregado_raw or 0)
            except (TypeError, ValueError):
                carregado = 0.0

            details['items'].append(
                {
                    'codigo_produto': codigo_produto or '',
                    'sequencia': sequencia or '',
                    'produto': produto_nome or '',
                    'reservado': reservado,
                    'separado': separado,
                    'carregado': carregado,
                    'kpi_status': calculate_order_kpi(reservado, separado, carregado),
                }
            )

        return details, None
    except Error as e:
        print(f"Erro ao carregar detalhes logísticos do pedido {pedido_value}: {e}")
        return None, {'message': 'Erro ao carregar detalhes do pedido.', 'status': 500}
    finally:
        if conn:
            conn.close()


@app.route('/orders/<path:pedido>/details')
@login_required
def order_details(pedido):
    details, error = fetch_order_details(pedido)
    if error:
        status_code = error.get('status', 500)
        return jsonify({'error': error.get('message', 'Erro ao carregar detalhes do pedido.')}), status_code
    return jsonify(details)


@app.route('/orders/<path:pedido>/logistics_details')
@login_required
def order_logistics_details(pedido):
    details, error = fetch_logistics_order_details(pedido)
    if error:
        status_code = error.get('status', 500)
        return jsonify({'error': error.get('message', 'Erro ao carregar detalhes do pedido.')}), status_code
    return jsonify(details)


@app.route('/orders_list')
@login_required
def orders_list():
    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    start_date_param = request.args.get('start_date')
    end_date_param = request.args.get('end_date')
    load_lots_param = [
        value.strip() for value in request.args.getlist('load_lots') if value and value.strip()
    ]
    production_lots_param = [
        value.strip() for value in request.args.getlist('production_lots') if value and value.strip()
    ]
    line_param = [
        value.strip() for value in request.args.getlist('lines') if value and value.strip()
    ]
    approval_status_param = []
    for raw_value in request.args.getlist('approval_statuses'):
        if raw_value is None:
            continue
        code = (raw_value or '').strip().upper()
        if code in ORDER_APPROVAL_STATUS_LABELS:
            approval_status_param.append(code)
    situation_param = []
    for raw_value in request.args.getlist('situations'):
        if raw_value is None:
            continue
        code = (raw_value or '').strip().upper()
        if code in ORDER_SITUATION_LABELS:
            situation_param.append(code)

    column_filters = {
        'filter_pedido': (request.args.get('filter_pedido') or '').strip(),
        'filter_seq_lote': (request.args.get('filter_seq_lote') or '').strip(),
        'filter_cliente_codigo': (request.args.get('filter_cliente_codigo') or '').strip(),
        'filter_cliente_nome': (request.args.get('filter_cliente_nome') or '').strip(),
        'filter_cidade_uf': (request.args.get('filter_cidade_uf') or '').strip(),
        'filter_quantidade_total': (request.args.get('filter_quantidade_total') or '').strip(),
        'filter_reservado': (request.args.get('filter_reservado') or '').strip(),
        'filter_separado': (request.args.get('filter_separado') or '').strip(),
        'filter_carregado': (request.args.get('filter_carregado') or '').strip(),
        'filter_linha': (request.args.get('filter_linha') or '').strip(),
    }

    sort_by_param = (request.args.get('sort_by') or 'pedido').strip()
    sort_order_param = (request.args.get('sort_order') or 'desc').strip().lower()

    allowed_sort_columns = {
        'pedido',
        'lcaseque',
        'cliente_codigo',
        'cliente_nome',
        'cidade_uf',
        'quantidade_total',
        'reservado',
        'separado',
        'carregado',
        'linha',
    }

    if sort_by_param not in allowed_sort_columns:
        sort_by_param = 'pedido'

    if sort_order_param not in {'asc', 'desc'}:
        sort_order_param = 'desc'

    filters = {
        'load_lot': (request.args.get('load_lot') or '').strip() or None,
        'load_lots': load_lots_param,
        'production_lots': production_lots_param,
        'lines': line_param,
        'line': (request.args.get('line') or '').strip() or None,
        'start_date': (start_date_param or '').strip() or None,
        'end_date': (end_date_param or '').strip() or None,
        'sort_by': sort_by_param,
        'sort_order': sort_order_param,
        'approval_statuses': approval_status_param,
        'situations': situation_param,
    }
    filters.update(column_filters)

    query_filters = filters.copy()
    if 'start_date' not in request.args and 'end_date' not in request.args:
        query_filters['start_date'] = first_day_of_month.strftime('%Y-%m-%d')
        query_filters['end_date'] = last_day_of_month.strftime('%Y-%m-%d')

    orders, error_message = fetch_orders_from_integrated_view(query_filters)

    if error_message:
        flash(error_message, 'danger')

    totals = {
        'quantidade_total': sum(order['quantidade_total'] for order in orders),
        'reservado': sum(order['reservado'] for order in orders),
        'separado': sum(order['separado'] for order in orders),
        'carregado': sum(order['carregado'] for order in orders),
    }

    return render_template(
        'orders_list.html',
        orders=orders,
        filters=filters,
        load_lot_options=get_distinct_load_lots(),
        production_lot_options=get_distinct_production_lots(),
        product_line_options=get_distinct_product_lines(),
        approval_status_options=MAP_APPROVAL_STATUS_OPTIONS,
        situation_options=MAP_SITUATION_OPTIONS,
        totals=totals,
        sort_by=sort_by_param,
        sort_order=sort_order_param,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/load_lots')
@login_required
def load_lots_view():
    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()

    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except ValueError:
            return None

    start_date = parse_date(start_date_param)
    end_date = parse_date(end_date_param)

    if start_date_param and start_date is None:
        flash('Data inicial inválida. Ajuste o filtro e tente novamente.', 'warning')
        start_date_param = ''
    if end_date_param and end_date is None:
        flash('Data final inválida. Ajuste o filtro e tente novamente.', 'warning')
        end_date_param = ''

    if not start_date and not end_date:
        start_date = first_day_of_month
        end_date = last_day_of_month
        start_date_param = start_date.strftime('%Y-%m-%d')
        end_date_param = end_date.strftime('%Y-%m-%d')

    summary_data, summary_error = fetch_load_lots_summary(start_date, end_date)
    if summary_error:
        flash(summary_error, 'danger')

    filters = {
        'start_date': start_date_param,
        'end_date': end_date_param,
    }

    period_display = {
        'start': start_date.strftime('%d/%m/%Y') if start_date else '',
        'end': end_date.strftime('%d/%m/%Y') if end_date else '',
    }

    return render_template(
        'load_lots.html',
        page_title="Lotes de Carga",
        summary=summary_data,
        filters=filters,
        period_display=period_display,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/load_lots/route_planner')
@login_required
def load_lot_route_planner():
    today = datetime.date.today()
    first_day = today.replace(day=1)
    last_day = first_day.replace(day=calendar.monthrange(today.year, today.month)[1])

    user_id = session.get('user_id')
    is_map_data_request = (request.args.get('map_data') or '').strip() == '1'
    saved_filters = {}
    if user_id:
        raw_saved_filters = get_user_parameters(user_id, LOAD_ROUTE_FILTERS_PARAM_NAME)
        if raw_saved_filters:
            try:
                parsed_filters = json.loads(raw_saved_filters)
                if isinstance(parsed_filters, dict):
                    saved_filters = parsed_filters
            except (json.JSONDecodeError, TypeError):
                saved_filters = {}

    def clean_string(value):
        if value is None:
            return ''
        return str(value).strip()

    def clean_list(values, allow_blank=False):
        if not values:
            return []
        if isinstance(values, str):
            values_iterable = [values]
        else:
            try:
                values_iterable = list(values)
            except TypeError:
                values_iterable = []
        cleaned = []
        for value in values_iterable:
            text = clean_string(value)
            if text:
                cleaned.append(text)
            elif allow_blank:
                if value is None:
                    continue
                if isinstance(value, str):
                    if value.strip() == '':
                        cleaned.append('')
                elif text == '':
                    cleaned.append('')
        return cleaned

    def deduplicate_preserve_order(items):
        seen = set()
        result = []
        for item in items:
            if item not in seen:
                seen.add(item)
                result.append(item)
        return result

    reset_param = clean_string(request.args.get('reset')).lower()
    ignore_saved_defaults = reset_param in {'1', 'true', 'yes', 'on'}

    start_date_param = clean_string(request.args.get('start_date'))
    end_date_param = clean_string(request.args.get('end_date'))
    production_lots_param = deduplicate_preserve_order(clean_list(request.args.getlist('production_lots')))

    if not start_date_param and not ignore_saved_defaults:
        start_date_param = clean_string(saved_filters.get('start_date'))
    if not end_date_param and not ignore_saved_defaults:
        end_date_param = clean_string(saved_filters.get('end_date'))
    if not production_lots_param and not ignore_saved_defaults:
        production_lots_param = deduplicate_preserve_order(clean_list(saved_filters.get('production_lots')))

    missing_production_lot_param = clean_string(request.args.get('missing_production_lot')).lower()
    allowed_missing_values = {'', 'yes', 'no'}
    if missing_production_lot_param not in allowed_missing_values:
        missing_production_lot_param = ''
    if not missing_production_lot_param and not ignore_saved_defaults:
        saved_missing = clean_string(saved_filters.get('missing_production_lot')).lower()
        if saved_missing in allowed_missing_values:
            missing_production_lot_param = saved_missing

    approval_status_param = []
    for raw_value in request.args.getlist('approval_statuses'):
        code = clean_string(raw_value).upper()
        if code in ORDER_APPROVAL_STATUS_LABELS and code not in approval_status_param:
            approval_status_param.append(code)
    if not approval_status_param and not ignore_saved_defaults:
        saved_approval_statuses = [
            code.upper()
            for code in deduplicate_preserve_order(clean_list(saved_filters.get('approval_statuses')))
            if code.upper() in ORDER_APPROVAL_STATUS_LABELS
        ]
        approval_status_param = saved_approval_statuses

    situation_param = []
    for raw_value in request.args.getlist('situations'):
        code = clean_string(raw_value).upper()
        if code in ORDER_SITUATION_LABELS and code not in situation_param:
            situation_param.append(code)
    if not situation_param and not ignore_saved_defaults:
        saved_situations = [
            code.upper()
            for code in deduplicate_preserve_order(clean_list(saved_filters.get('situations'), allow_blank=True))
            if code.upper() in ORDER_SITUATION_LABELS
        ]
        situation_param = saved_situations

    separation_stage_param = []
    for raw_value in request.args.getlist('separation_stage'):
        code = clean_string(raw_value).lower()
        if code in VALID_SEPARATION_STAGE_CODES and code not in separation_stage_param:
            separation_stage_param.append(code)
    if not separation_stage_param and not ignore_saved_defaults:
        saved_stages = []
        for code in deduplicate_preserve_order(clean_list(saved_filters.get('separation_stages'))):
            normalized = code.lower()
            if normalized in VALID_SEPARATION_STAGE_CODES and normalized not in saved_stages:
                saved_stages.append(normalized)
        separation_stage_param = saved_stages

    production_lots_param = deduplicate_preserve_order(production_lots_param)

    document_sources_param = clean_string(request.args.get('document_sources')).lower()
    if not document_sources_param and not ignore_saved_defaults:
        document_sources_param = clean_string(saved_filters.get('document_sources')).lower()
    if document_sources_param not in MAP_DOCUMENT_SOURCE_RECORD_TYPES:
        document_sources_param = 'both'
    selected_record_types = MAP_DOCUMENT_SOURCE_RECORD_TYPES.get(document_sources_param, MAP_DOCUMENT_SOURCE_RECORD_TYPES['both'])

    filters = {
        'start_date': start_date_param,
        'end_date': end_date_param,
        'production_lots': production_lots_param,
        'approval_statuses': approval_status_param,
        'situations': situation_param,
        'separation_stages': separation_stage_param,
        'missing_production_lot': missing_production_lot_param,
        'document_sources': document_sources_param,
    }

    query_filters = {
        'production_lots': production_lots_param,
        'approval_statuses': approval_status_param,
        'situations': situation_param,
        'sort_by': 'pedido',
        'sort_order': 'desc',
        'record_types': selected_record_types,
    }

    if start_date_param:
        query_filters['start_date'] = start_date_param
    else:
        filters['start_date'] = first_day.strftime('%Y-%m-%d')
        query_filters['start_date'] = filters['start_date']

    if end_date_param:
        query_filters['end_date'] = end_date_param
    else:
        filters['end_date'] = last_day.strftime('%Y-%m-%d')
        query_filters['end_date'] = filters['end_date']

    orders, error_message = fetch_orders_from_integrated_view(query_filters)
    if error_message:
        if is_map_data_request:
            return jsonify({'success': False, 'message': error_message}), 500
        flash(error_message, 'danger')

    stage_filters = set(separation_stage_param)
    if stage_filters and stage_filters == VALID_SEPARATION_STAGE_CODES:
        stage_filters = set()

    def matches_stage(order):
        if not stage_filters:
            return True
        kpi = order.get('kpi_status')
        separado = order.get('separado', 0)

        def stage_matches(stage_code):
            if stage_code == 'zero':
                return separado == 0 or kpi == 0
            if stage_code == 'partial':
                return kpi == 1
            if stage_code == 'total':
                return kpi in (2, 3)
            return True

        return any(stage_matches(code) for code in stage_filters)

    filtered_orders = [order for order in orders if matches_stage(order)]

    def has_production_lot(order):
        return bool((order.get('production_lots_display') or '').strip())

    def is_assistance_record(order):
        record_type = (order.get('record_type') or '').strip().lower()
        return record_type == 'assistencia_tecnica'

    if missing_production_lot_param == 'yes':
        filtered_orders = [
            order for order in filtered_orders
            if is_assistance_record(order) or not has_production_lot(order)
        ]
    elif missing_production_lot_param == 'no':
        filtered_orders = [
            order for order in filtered_orders
            if is_assistance_record(order) or has_production_lot(order)
        ]

    def extract_production_lots(display_value):
        entries = []
        if not display_value:
            return entries

        def get_description(raw_label):
            parts = raw_label.split(' - ', 1)
            if len(parts) == 2:
                return parts[1].strip() or raw_label.strip()
            return raw_label.strip()

        def get_group_key(raw_label, prefix_length=9):
            description = get_description(raw_label)
            if not description:
                return ''
            return description[:prefix_length].strip().lower()

        for chunk in display_value.split(';'):
            token = chunk.strip()
            if not token:
                continue
            code_part = token.split(' - ')[0].strip()
            description = get_description(token)
            entries.append(
                {
                    'code': code_part,
                    'label': token,
                    'description': description,
                    'group_key': get_group_key(token),
                }
            )
        return entries

    selected_production_lot_codes = {code for code in production_lots_param if code}
    if selected_production_lot_codes and missing_production_lot_param != 'yes':
        def order_matches_selected_lots(order):
            entries = extract_production_lots(order.get('production_lots_display', ''))
            order_codes = {entry['code'] for entry in entries if entry['code']}
            if not order_codes:
                return False
            return bool(order_codes.intersection(selected_production_lot_codes))

        filtered_orders = [order for order in filtered_orders if order_matches_selected_lots(order)]

    def decimal_from(value):
        if isinstance(value, Decimal):
            return value
        if value in (None, ''):
            return Decimal(0)
        try:
            return Decimal(str(value))
        except (InvalidOperation, ValueError, TypeError):
            return Decimal(0)

    state_distribution = {uf: Decimal(0) for uf in BRAZIL_STATE_CODES}
    for order in filtered_orders:
        state_code = clean_string(order.get('estado')).upper()
        if not state_code or state_code not in state_distribution:
            continue
        separado_value = decimal_from(order.get('separado'))
        carregado_value = decimal_from(order.get('carregado'))
        state_distribution[state_code] += separado_value - carregado_value

    distribution_report_payload = {}
    for uf, quantity in state_distribution.items():
        try:
            distribution_report_payload[uf] = float(quantity)
        except (InvalidOperation, ValueError, TypeError):
            distribution_report_payload[uf] = 0.0

    lot_display_map = {}
    lot_codes_in_order = []
    code_group_map = {}
    group_display_map = {}
    lot_groups_in_order = []
    assistance_without_lot = False
    for order in filtered_orders:
        entries = extract_production_lots(order.get('production_lots_display', ''))
        is_assistance = (order.get('record_type') or '').strip().lower() == 'assistencia_tecnica'
        if is_assistance and not entries:
            assistance_without_lot = True
        for entry in entries:
            code = entry['code']
            group_key = entry.get('group_key', '')
            if code and code not in lot_display_map:
                lot_display_map[code] = entry['label']
                lot_codes_in_order.append(code)
            if code and group_key:
                code_group_map[code] = group_key
                if group_key not in group_display_map:
                    raw_description = entry.get('description') or ''
                    display_label = raw_description[:9].strip() if raw_description else ''
                    if not display_label:
                        display_label = (entry.get('label') or '')[:9].strip()
                    group_display_map[group_key] = display_label or group_key.upper()
            if group_key and group_key not in lot_groups_in_order:
                lot_groups_in_order.append(group_key)

    if assistance_without_lot:
        assistance_code = '__assist__'
        if assistance_code not in lot_display_map:
            lot_display_map[assistance_code] = 'Assistência Técnica'
        if assistance_code not in lot_codes_in_order:
            lot_codes_in_order.append(assistance_code)

    stage_border_colors = {
        'zero': '#dc2626',
        'partial': '#facc15',
        'total': '#16a34a',
        'carregado': '#2563eb',
    }
    stage_color_values = {color.lower() for color in stage_border_colors.values()}

    base_color_palette = [
        '#2563eb', '#0ea5e9', '#14b8a6', '#22c55e', '#f97316', '#f43f5e',
        '#a855f7', '#eab308', '#ec4899', '#10b981', '#6366f1', '#fb7185',
    ]
    color_palette = [color for color in base_color_palette if color.lower() not in stage_color_values]
    if not color_palette:
        color_palette = ['#9333ea', '#0ea5e9', '#f97316', '#ec4899']
    group_color_map = {}
    for idx, group_key in enumerate(lot_groups_in_order):
        group_color_map[group_key] = color_palette[idx % len(color_palette)]

    lot_color_map = {}
    next_color_index = 0
    for code in lot_codes_in_order:
        group_key = code_group_map.get(code)
        if group_key:
            lot_color_map[code] = group_color_map[group_key]
        else:
            lot_color_map[code] = color_palette[next_color_index % len(color_palette)]
            next_color_index += 1

    if assistance_without_lot:
        lot_color_map['__assist__'] = '#7c3aed'

    geocode_cache = GEOCODE_CACHE

    map_orders = []
    for order in filtered_orders:
        record_type_value = (order.get('record_type') or '').strip().lower()
        kpi_status = order.get('kpi_status')
        if kpi_status == 1:
            stage_key = 'partial'
        elif kpi_status == 2:
            stage_key = 'total'
        elif kpi_status == 3:
            stage_key = 'carregado'
        else:
            stage_key = 'zero'
        marker_border = stage_border_colors.get(stage_key, '#1f2937')

        latitude = normalize_coordinate_value(order.get('latitude'))
        longitude = normalize_coordinate_value(order.get('longitude'))
        coordinate_source = order.get('coordinate_source') or 'database'
        if (
            latitude is None or longitude is None
            or isclose(latitude, 0.0, abs_tol=1e-6)
            or isclose(longitude, 0.0, abs_tol=1e-6)
        ):
            geocoded_coord = geocode_city_state(order.get('cidade'), order.get('estado'), geocode_cache)
            if geocoded_coord:
                latitude, longitude = geocoded_coord
                coordinate_source = 'geocode'

        document_date_value = order.get('document_date')
        if isinstance(document_date_value, datetime.datetime):
            document_date_render = document_date_value.strftime('%Y-%m-%d')
        elif isinstance(document_date_value, datetime.date):
            document_date_render = document_date_value.strftime('%Y-%m-%d')
        else:
            document_date_render = document_date_value

        lot_entries = extract_production_lots(order.get('production_lots_display', ''))
        primary_lot_code = ''
        primary_lot_label = ''
        marker_fill = '#1f2937'
        for entry in lot_entries:
            if entry['code'] in lot_color_map:
                primary_lot_code = entry['code']
                primary_lot_label = entry['label']
                marker_fill = lot_color_map[entry['code']]
                break
        if record_type_value == 'assistencia_tecnica' and not primary_lot_code:
            primary_lot_code = '__assist__'
            primary_lot_label = 'Assistência Técnica'
            if '__assist__' not in lot_color_map:
                lot_color_map['__assist__'] = '#7c3aed'
            marker_fill = lot_color_map['__assist__']
        map_orders.append(
            {
                'pedido': order.get('pedido'),
                'unique_id': order.get('unique_id'),
                'record_type': order.get('record_type'),
                'record_type_label': order.get('record_type_label'),
                'can_show_details': order.get('can_show_details', True),
                'document_date': document_date_render,
                'cliente': order.get('cliente_nome'),
                'document_id': order.get('document_id'),
                'cidade': order.get('cidade'),
                'estado': order.get('estado'),
                'linha': order.get('linha'),
                'quantidade_total': order.get('quantidade_total'),
                'latitude': latitude,
                'longitude': longitude,
                'kpi_status': order.get('kpi_status'),
                'reservado': order.get('reservado'),
                'separado': order.get('separado'),
                'carregado': order.get('carregado'),
                'production_lots_display': order.get('production_lots_display'),
                'primary_lot_code': primary_lot_code,
                'primary_lot_label': primary_lot_label,
                'marker_fill': marker_fill,
                'stage_key': stage_key,
                'marker_border': marker_border,
                'coordinate_source': coordinate_source,
            }
        )

    def serialize_map_order(item):
        sanitized = {}
        for key, value in item.items():
            if isinstance(value, Decimal):
                sanitized[key] = float(value)
            else:
                sanitized[key] = value
        return sanitized

    def has_valid_coordinates(item):
        lat = item.get('latitude')
        lon = item.get('longitude')
        if lat is None or lon is None:
            return False
        try:
            return not isclose(float(lat), 0.0, abs_tol=1e-6) and not isclose(float(lon), 0.0, abs_tol=1e-6)
        except (TypeError, ValueError):
            return False

    serialized_map_orders = [serialize_map_order(item) for item in map_orders]
    orders_with_coordinates = sum(1 for item in serialized_map_orders if has_valid_coordinates(item))
    map_orders_summary = {
        'total_orders': len(serialized_map_orders),
        'orders_with_coordinates': orders_with_coordinates,
        'orders_without_coordinates': len(serialized_map_orders) - orders_with_coordinates,
    }
    record_type_breakdown = {}
    for item in serialized_map_orders:
        key = (item.get('record_type') or '').strip().lower()
        record_type_breakdown[key] = record_type_breakdown.get(key, 0) + 1
    map_orders_summary['record_type_breakdown'] = record_type_breakdown

    if is_map_data_request:
        payload = {
            'success': True,
            'orders': serialized_map_orders,
            'summary': map_orders_summary,
        }
        return jsonify(payload)

    legend_entries = [
        {
            'code': code,
            'label': lot_display_map.get(code, code),
            'color': lot_color_map.get(code),
            'group_key': code_group_map.get(code, ''),
        }
        for code in sorted(lot_codes_in_order)
    ]
    grouped_entries = {}
    for entry in legend_entries:
        group_key = entry['group_key'] or ''
        grouped_entries.setdefault(group_key, []).append(entry)
    lot_color_legend_groups = []
    for group_key in lot_groups_in_order:
        items = grouped_entries.pop(group_key, [])
        if not items:
            continue
        items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': group_key,
                'label': group_display_map.get(group_key) or group_key.upper(),
                'items': items,
            }
        )
    ungrouped_items = grouped_entries.pop('', [])
    if ungrouped_items:
        ungrouped_items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': '',
                'label': '',
                'items': ungrouped_items,
            }
        )
    for leftover_key in sorted(grouped_entries.keys()):
        items = grouped_entries[leftover_key]
        if not items:
            continue
        items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': leftover_key,
                'label': group_display_map.get(leftover_key) or leftover_key.upper(),
                'items': items,
            }
        )
    lot_color_legend = [
        {'code': entry['code'], 'label': entry['label'], 'color': entry['color']}
        for entry in legend_entries
    ]

    def format_period(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
        except ValueError:
            return ''

    period_display = {
        'start': format_period(query_filters.get('start_date')),
        'end': format_period(query_filters.get('end_date')),
    }

    return render_template(
        'load_route_planner.html',
        page_title="Mapa Interativo",
        orders=filtered_orders,
        map_orders_payload=serialized_map_orders,
        map_orders_summary=map_orders_summary,
        filters=filters,
        production_lot_options=get_distinct_production_lots(),
        approval_status_options=ORDER_APPROVAL_STATUS_OPTIONS,
        situation_options=ORDER_SITUATION_OPTIONS,
        production_lot_colors=lot_color_map,
        lot_color_legend=lot_color_legend,
        lot_color_legend_groups=lot_color_legend_groups,
        stage_border_colors=stage_border_colors,
        separation_stages=separation_stage_param,
        separation_stage_options=SEPARATION_STAGE_OPTIONS,
        period_display=period_display,
        distribution_report_data=distribution_report_payload,
        document_source_options=MAP_DOCUMENT_SOURCE_OPTIONS,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
    )


@app.route('/load_lots/route_planner_2')
@login_required
def load_lot_route_planner_v2():
    today = datetime.date.today()
    first_day = today.replace(day=1)
    last_day = first_day.replace(day=calendar.monthrange(today.year, today.month)[1])

    user_id = session.get('user_id')
    is_map_data_request = (request.args.get('map_data') or '').strip() == '1'
    saved_filters = {}
    if user_id:
        raw_saved_filters = get_user_parameters(user_id, LOAD_ROUTE_FILTERS_PARAM_NAME_V2)
        if raw_saved_filters:
            try:
                parsed_filters = json.loads(raw_saved_filters)
                if isinstance(parsed_filters, dict):
                    saved_filters = parsed_filters
            except (json.JSONDecodeError, TypeError):
                saved_filters = {}

    def clean_string(value):
        if value is None:
            return ''
        return str(value).strip()

    def clean_list(values, allow_blank=False):
        if not values:
            return []
        if isinstance(values, str):
            values_iterable = [values]
        else:
            try:
                values_iterable = list(values)
            except TypeError:
                values_iterable = []
        cleaned = []
        for value in values_iterable:
            text = clean_string(value)
            if text:
                cleaned.append(text)
            elif allow_blank:
                if value is None:
                    continue
                if isinstance(value, str):
                    if value.strip() == '':
                        cleaned.append('')
                elif text == '':
                    cleaned.append('')
        return cleaned

    def deduplicate_preserve_order(items):
        seen = set()
        result = []
        for item in items:
            if item not in seen:
                seen.add(item)
                result.append(item)
        return result

    reset_param = clean_string(request.args.get('reset')).lower()
    ignore_saved_defaults = reset_param in {'1', 'true', 'yes', 'on'}

    start_date_param = clean_string(request.args.get('start_date'))
    end_date_param = clean_string(request.args.get('end_date'))
    production_lots_param = deduplicate_preserve_order(clean_list(request.args.getlist('production_lots')))

    if not start_date_param and not ignore_saved_defaults:
        start_date_param = clean_string(saved_filters.get('start_date'))
    if not end_date_param and not ignore_saved_defaults:
        end_date_param = clean_string(saved_filters.get('end_date'))
    if not production_lots_param and not ignore_saved_defaults:
        production_lots_param = deduplicate_preserve_order(clean_list(saved_filters.get('production_lots')))

    missing_production_lot_param = clean_string(request.args.get('missing_production_lot')).lower()
    allowed_missing_values = {'', 'yes', 'no'}
    if missing_production_lot_param not in allowed_missing_values:
        missing_production_lot_param = ''
    if not missing_production_lot_param and not ignore_saved_defaults:
        saved_missing = clean_string(saved_filters.get('missing_production_lot')).lower()
        if saved_missing in allowed_missing_values:
            missing_production_lot_param = saved_missing

    approval_status_param = []
    for raw_value in request.args.getlist('approval_statuses'):
        code = clean_string(raw_value).upper()
        if code in MAP_APPROVAL_STATUS_CODES and code not in approval_status_param:
            approval_status_param.append(code)
    if not approval_status_param and not ignore_saved_defaults:
        saved_approval_statuses = [
            code.upper()
            for code in deduplicate_preserve_order(clean_list(saved_filters.get('approval_statuses')))
            if code.upper() in MAP_APPROVAL_STATUS_CODES
        ]
        approval_status_param = saved_approval_statuses

    situation_param = []
    for raw_value in request.args.getlist('situations'):
        code = clean_string(raw_value).upper()
        if code in MAP_SITUATION_CODES and code not in situation_param:
            situation_param.append(code)
    if not situation_param and not ignore_saved_defaults:
        saved_situations = [
            code.upper()
            for code in deduplicate_preserve_order(clean_list(saved_filters.get('situations'), allow_blank=True))
            if code.upper() in MAP_SITUATION_CODES
        ]
        situation_param = saved_situations

    separation_stage_param = []
    for raw_value in request.args.getlist('separation_stage'):
        code = clean_string(raw_value).lower()
        if code in VALID_SEPARATION_STAGE_CODES and code not in separation_stage_param:
            separation_stage_param.append(code)
    if not separation_stage_param and not ignore_saved_defaults:
        saved_stages = []
        for code in deduplicate_preserve_order(clean_list(saved_filters.get('separation_stages'))):
            normalized = code.lower()
            if normalized in VALID_SEPARATION_STAGE_CODES:
                if normalized not in saved_stages:
                    saved_stages.append(normalized)
        separation_stage_param = saved_stages

    production_lots_param = deduplicate_preserve_order(production_lots_param)

    document_sources_param = clean_string(request.args.get('document_sources')).lower()
    if not document_sources_param and not ignore_saved_defaults:
        document_sources_param = clean_string(saved_filters.get('document_sources')).lower()
    if document_sources_param not in MAP_DOCUMENT_SOURCE_RECORD_TYPES:
        document_sources_param = 'both'
    selected_record_types = MAP_DOCUMENT_SOURCE_RECORD_TYPES.get(
        document_sources_param,
        MAP_DOCUMENT_SOURCE_RECORD_TYPES['both'],
    )

    filters = {
        'start_date': start_date_param,
        'end_date': end_date_param,
        'production_lots': production_lots_param,
        'approval_statuses': approval_status_param,
        'situations': situation_param,
        'separation_stages': separation_stage_param,
        'missing_production_lot': missing_production_lot_param,
        'document_sources': document_sources_param,
    }

    query_filters = {
        'production_lots': production_lots_param,
        'approval_statuses': approval_status_param,
        'situations': situation_param,
        'sort_by': 'pedido',
        'sort_order': 'desc',
        'record_types': selected_record_types,
    }

    if start_date_param:
        query_filters['start_date'] = start_date_param
    else:
        filters['start_date'] = first_day.strftime('%Y-%m-%d')
        query_filters['start_date'] = filters['start_date']

    if end_date_param:
        query_filters['end_date'] = end_date_param
    else:
        filters['end_date'] = last_day.strftime('%Y-%m-%d')
        query_filters['end_date'] = filters['end_date']

    orders, error_message = fetch_orders_from_integrated_view(query_filters)
    if error_message:
        if is_map_data_request:
            return jsonify({'success': False, 'message': error_message}), 500
        flash(error_message, 'danger')

    orders = orders or []

    def to_float(value):
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, Decimal):
            try:
                return float(value)
            except (InvalidOperation, ValueError):
                return 0.0
        if value in (None, ''):
            return 0.0
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    def determine_stage_key_from_values(reservado, separado, carregado):
        reservado_value = to_float(reservado)
        separado_value = to_float(separado)
        carregado_value = to_float(carregado)
        rel_tol = 1e-6
        abs_tol = 1e-6

        if isclose(separado_value, 0.0, rel_tol=rel_tol, abs_tol=abs_tol):
            return 'zero'

        if (
            not isclose(separado_value, 0.0, rel_tol=rel_tol, abs_tol=abs_tol)
            and isclose(carregado_value, separado_value, rel_tol=rel_tol, abs_tol=abs_tol)
        ):
            return 'carregado'

        if isclose(separado_value, reservado_value, rel_tol=rel_tol, abs_tol=abs_tol):
            return 'total'

        if separado_value < reservado_value and not isclose(separado_value, reservado_value, rel_tol=rel_tol, abs_tol=abs_tol):
            return 'partial'

        if separado_value > reservado_value and not isclose(separado_value, reservado_value, rel_tol=rel_tol, abs_tol=abs_tol):
            return 'total'

        return 'partial'

    for order in orders:
        order['stage_key'] = determine_stage_key_from_values(
            order.get('reservado'),
            order.get('separado'),
            order.get('carregado'),
        )

    stage_filters = set(separation_stage_param)
    if stage_filters and stage_filters == VALID_SEPARATION_STAGE_CODES:
        stage_filters = set()

    def matches_stage(order):
        if not stage_filters:
            return True
        stage_key = order.get('stage_key') or determine_stage_key_from_values(
            order.get('reservado'),
            order.get('separado'),
            order.get('carregado'),
        )
        return stage_key in stage_filters

    filtered_orders = [order for order in orders if matches_stage(order)]

    def has_production_lot(order):
        return bool((order.get('production_lots_display') or '').strip())

    def is_assistance_record(order):
        record_type = (order.get('record_type') or '').strip().lower()
        return record_type == 'assistencia_tecnica'

    if missing_production_lot_param == 'yes':
        filtered_orders = [
            order for order in filtered_orders
            if is_assistance_record(order) or not has_production_lot(order)
        ]
    elif missing_production_lot_param == 'no':
        filtered_orders = [
            order for order in filtered_orders
            if is_assistance_record(order) or has_production_lot(order)
        ]

    def extract_production_lots(display_value):
        entries = []
        if not display_value:
            return entries

        def get_description(raw_label):
            parts = raw_label.split(' - ', 1)
            if len(parts) == 2:
                return parts[1].strip() or raw_label.strip()
            return raw_label.strip()

        def get_group_key(raw_label, prefix_length=9):
            description = get_description(raw_label)
            if not description:
                return ''
            return description[:prefix_length].strip().lower()

        for chunk in display_value.split(';'):
            token = chunk.strip()
            if not token:
                continue
            code_part = token.split(' - ')[0].strip()
            description = get_description(token)
            entries.append(
                {
                    'code': code_part,
                    'label': token,
                    'description': description,
                    'group_key': get_group_key(token),
                }
            )
        return entries

    selected_production_lot_codes = {code for code in production_lots_param if code}
    if selected_production_lot_codes and missing_production_lot_param != 'yes':
        def order_matches_selected_lots(order):
            entries = extract_production_lots(order.get('production_lots_display', ''))
            order_codes = {entry['code'] for entry in entries if entry['code']}
            if not order_codes:
                return False
            return bool(order_codes.intersection(selected_production_lot_codes))

        filtered_orders = [order for order in filtered_orders if order_matches_selected_lots(order)]

    def decimal_from(value):
        if isinstance(value, Decimal):
            return value
        if value in (None, ''):
            return Decimal(0)
        try:
            return Decimal(str(value))
        except (InvalidOperation, ValueError, TypeError):
            return Decimal(0)

    state_distribution = {uf: Decimal(0) for uf in BRAZIL_STATE_CODES}
    for order in filtered_orders:
        state_code = clean_string(order.get('estado')).upper()
        if not state_code or state_code not in state_distribution:
            continue
        separado_value = decimal_from(order.get('separado'))
        carregado_value = decimal_from(order.get('carregado'))
        state_distribution[state_code] += separado_value - carregado_value

    distribution_report_payload = {}
    for uf, quantity in state_distribution.items():
        try:
            distribution_report_payload[uf] = float(quantity)
        except (InvalidOperation, ValueError, TypeError):
            distribution_report_payload[uf] = 0.0

    lot_display_map = {}
    lot_codes_in_order = []
    code_group_map = {}
    group_display_map = {}
    lot_groups_in_order = []
    assistance_without_lot = False
    for order in filtered_orders:
        entries = extract_production_lots(order.get('production_lots_display', ''))
        is_assistance = (order.get('record_type') or '').strip().lower() == 'assistencia_tecnica'
        if is_assistance and not entries:
            assistance_without_lot = True
        for entry in entries:
            code = entry['code']
            group_key = entry.get('group_key', '')
            if code and code not in lot_display_map:
                lot_display_map[code] = entry['label']
                lot_codes_in_order.append(code)
            if code and group_key:
                code_group_map[code] = group_key
                if group_key not in group_display_map:
                    raw_description = entry.get('description') or ''
                    display_label = raw_description[:9].strip() if raw_description else ''
                    if not display_label:
                        display_label = (entry.get('label') or '')[:9].strip()
                    group_display_map[group_key] = display_label or group_key.upper()
            if group_key and group_key not in lot_groups_in_order:
                lot_groups_in_order.append(group_key)

    if assistance_without_lot:
        assistance_code = '__assist__'
        if assistance_code not in lot_display_map:
            lot_display_map[assistance_code] = 'Assistência Técnica'
        if assistance_code not in lot_codes_in_order:
            lot_codes_in_order.append(assistance_code)

    stage_border_colors = {
        'zero': '#dc2626',
        'partial': '#facc15',
        'total': '#16a34a',
        'carregado': '#2563eb',
    }
    stage_color_values = {color.lower() for color in stage_border_colors.values()}

    base_color_palette = [
        '#2563eb', '#0ea5e9', '#14b8a6', '#22c55e', '#f97316', '#f43f5e',
        '#a855f7', '#eab308', '#ec4899', '#10b981', '#6366f1', '#fb7185',
    ]
    color_palette = [color for color in base_color_palette if color.lower() not in stage_color_values]
    if not color_palette:
        color_palette = ['#9333ea', '#0ea5e9', '#f97316', '#ec4899']
    group_color_map = {}
    for idx, group_key in enumerate(lot_groups_in_order):
        group_color_map[group_key] = color_palette[idx % len(color_palette)]

    lot_color_map = {}
    next_color_index = 0
    for code in lot_codes_in_order:
        group_key = code_group_map.get(code)
        if group_key:
            lot_color_map[code] = group_color_map[group_key]
        else:
            lot_color_map[code] = color_palette[next_color_index % len(color_palette)]
            next_color_index += 1

    if assistance_without_lot:
        lot_color_map['__assist__'] = '#7c3aed'

    geocode_cache = GEOCODE_CACHE

    map_orders = []
    for order in filtered_orders:
        record_type_value = (order.get('record_type') or '').strip().lower()
        stage_key = order.get('stage_key') or determine_stage_key_from_values(
            order.get('reservado'),
            order.get('separado'),
            order.get('carregado'),
        )
        marker_border = stage_border_colors.get(stage_key, '#1f2937')

        latitude = normalize_coordinate_value(order.get('latitude'))
        longitude = normalize_coordinate_value(order.get('longitude'))
        coordinate_source = order.get('coordinate_source') or 'database'
        if (
            latitude is None or longitude is None
            or isclose(latitude, 0.0, abs_tol=1e-6)
            or isclose(longitude, 0.0, abs_tol=1e-6)
        ):
            geocoded_coord = geocode_city_state(order.get('cidade'), order.get('estado'), geocode_cache)
            if geocoded_coord:
                latitude, longitude = geocoded_coord
                coordinate_source = 'geocode'

        document_date_value = order.get('document_date')
        if isinstance(document_date_value, datetime.datetime):
            document_date_render = document_date_value.strftime('%Y-%m-%d')
        elif isinstance(document_date_value, datetime.date):
            document_date_render = document_date_value.strftime('%Y-%m-%d')
        else:
            document_date_render = document_date_value

        lot_entries = extract_production_lots(order.get('production_lots_display', ''))
        primary_lot_code = ''
        primary_lot_label = ''
        marker_fill = '#1f2937'
        for entry in lot_entries:
            if entry['code'] in lot_color_map:
                primary_lot_code = entry['code']
                primary_lot_label = entry['label']
                marker_fill = lot_color_map[entry['code']]
                break
        if record_type_value == 'assistencia_tecnica' and not primary_lot_code:
            primary_lot_code = '__assist__'
            primary_lot_label = 'Assistência Técnica'
            if '__assist__' not in lot_color_map:
                lot_color_map['__assist__'] = '#7c3aed'
            marker_fill = lot_color_map['__assist__']

        map_orders.append(
            {
                'pedido': order.get('pedido'),
                'unique_id': order.get('unique_id'),
                'record_type': order.get('record_type'),
                'record_type_label': order.get('record_type_label'),
                'can_show_details': order.get('can_show_details', True),
                'document_date': document_date_render,
                'cliente': order.get('cliente_nome'),
                'document_id': order.get('document_id'),
                'cidade': order.get('cidade'),
                'estado': order.get('estado'),
                'linha': order.get('linha'),
                'quantidade_total': order.get('quantidade_total'),
                'latitude': latitude,
                'longitude': longitude,
                'kpi_status': order.get('kpi_status'),
                'reservado': order.get('reservado'),
                'separado': order.get('separado'),
                'carregado': order.get('carregado'),
                'production_lots_display': order.get('production_lots_display'),
                'primary_lot_code': primary_lot_code,
                'primary_lot_label': primary_lot_label,
                'marker_fill': marker_fill,
                'stage_key': stage_key,
                'marker_border': marker_border,
                'coordinate_source': coordinate_source,
            }
        )

    def serialize_map_order(item):
        sanitized = {}
        for key, value in item.items():
            if isinstance(value, Decimal):
                sanitized[key] = float(value)
            else:
                sanitized[key] = value
        return sanitized

    def has_valid_coordinates(item):
        lat = item.get('latitude')
        lon = item.get('longitude')
        if lat is None or lon is None:
            return False
        try:
            return not isclose(float(lat), 0.0, abs_tol=1e-6) and not isclose(float(lon), 0.0, abs_tol=1e-6)
        except (TypeError, ValueError):
            return False

    serialized_map_orders = [serialize_map_order(item) for item in map_orders]
    orders_with_coordinates = sum(1 for item in serialized_map_orders if has_valid_coordinates(item))
    map_orders_summary = {
        'total_orders': len(serialized_map_orders),
        'orders_with_coordinates': orders_with_coordinates,
        'orders_without_coordinates': len(serialized_map_orders) - orders_with_coordinates,
    }

    if is_map_data_request:
        payload = {
            'success': True,
            'orders': serialized_map_orders,
            'summary': map_orders_summary,
        }
        return jsonify(payload)

    legend_entries = [
        {
            'code': code,
            'label': lot_display_map.get(code, code),
            'color': lot_color_map.get(code),
            'group_key': code_group_map.get(code, ''),
        }
        for code in sorted(lot_codes_in_order)
    ]
    grouped_entries = {}
    for entry in legend_entries:
        group_key = entry['group_key'] or ''
        grouped_entries.setdefault(group_key, []).append(entry)
    lot_color_legend_groups = []
    for group_key in lot_groups_in_order:
        items = grouped_entries.pop(group_key, [])
        if not items:
            continue
        items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': group_key,
                'label': group_display_map.get(group_key) or group_key.upper(),
                'items': items,
            }
        )
    ungrouped_items = grouped_entries.pop('', [])
    if ungrouped_items:
        ungrouped_items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': '',
                'label': '',
                'items': ungrouped_items,
            }
        )
    for leftover_key in sorted(grouped_entries.keys()):
        items = grouped_entries[leftover_key]
        if not items:
            continue
        items.sort(key=lambda item: item['code'])
        lot_color_legend_groups.append(
            {
                'key': leftover_key,
                'label': group_display_map.get(leftover_key) or leftover_key.upper(),
                'items': items,
            }
        )
    lot_color_legend = [
        {'code': entry['code'], 'label': entry['label'], 'color': entry['color']}
        for entry in legend_entries
    ]

    def format_period(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
        except ValueError:
            return ''

    period_display = {
        'start': format_period(query_filters.get('start_date')),
        'end': format_period(query_filters.get('end_date')),
    }

    return render_template(
        'load_route_planner_v2.html',
        page_title="Mapa Interativo 2",
        orders=filtered_orders,
        map_orders_payload=serialized_map_orders,
        map_orders_summary=map_orders_summary,
        filters=filters,
        production_lot_options=get_distinct_production_lots(),
        approval_status_options=MAP_APPROVAL_STATUS_OPTIONS,
        situation_options=MAP_SITUATION_OPTIONS,
        order_approval_status_options=ORDER_APPROVAL_STATUS_OPTIONS,
        assistance_status_options=ASSISTANCE_STATUS_OPTIONS,
        order_situation_options=ORDER_SITUATION_OPTIONS,
        assistance_situation_options=ASSISTANCE_SITUATION_OPTIONS,
        production_lot_colors=lot_color_map,
        lot_color_legend=lot_color_legend,
        lot_color_legend_groups=lot_color_legend_groups,
        stage_border_colors=stage_border_colors,
        separation_stages=separation_stage_param,
        separation_stage_options=SEPARATION_STAGE_OPTIONS,
        period_display=period_display,
        distribution_report_data=distribution_report_payload,
        document_source_options=MAP_DOCUMENT_SOURCE_OPTIONS,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
    )


@app.route('/load_lots/route_planner/save_filters', methods=['POST'])
@login_required
def save_load_lot_route_filters():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def clean_string(value):
        if value is None:
            return ''
        return str(value).strip()

    def clean_list(values, allow_blank=False):
        if not values:
            return []
        if isinstance(values, str):
            values_iterable = [values]
        else:
            try:
                values_iterable = list(values)
            except TypeError:
                values_iterable = []
        cleaned = []
        for value in values_iterable:
            text = clean_string(value)
            if text:
                cleaned.append(text)
            elif allow_blank:
                if value is None:
                    continue
                if isinstance(value, str):
                    if value.strip() == '':
                        cleaned.append('')
                elif text == '':
                    cleaned.append('')
        return cleaned

    def deduplicate_preserve_order(items):
        seen = set()
        result = []
        for item in items:
            if item not in seen:
                seen.add(item)
                result.append(item)
        return result

    sanitized_filters = {}

    start_date = clean_string(payload.get('start_date'))
    if start_date:
        try:
            datetime.datetime.strptime(start_date, '%Y-%m-%d')
        except ValueError:
            start_date = ''
    sanitized_filters['start_date'] = start_date

    end_date = clean_string(payload.get('end_date'))
    if end_date:
        try:
            datetime.datetime.strptime(end_date, '%Y-%m-%d')
        except ValueError:
            end_date = ''
    sanitized_filters['end_date'] = end_date

    allowed_missing_values = {'', 'yes', 'no'}
    missing_production_lot = clean_string(payload.get('missing_production_lot')).lower()
    if missing_production_lot not in allowed_missing_values:
        missing_production_lot = ''
    sanitized_filters['missing_production_lot'] = missing_production_lot

    allowed_status_codes = set(ORDER_APPROVAL_STATUS_LABELS.keys())
    approval_statuses = [
        code.upper()
        for code in deduplicate_preserve_order(clean_list(payload.get('approval_statuses')))
        if code.upper() in allowed_status_codes
    ]
    sanitized_filters['approval_statuses'] = approval_statuses

    allowed_situation_codes = set(ORDER_SITUATION_LABELS.keys())
    situations = [
        code.upper()
        for code in deduplicate_preserve_order(clean_list(payload.get('situations'), allow_blank=True))
        if code.upper() in allowed_situation_codes
    ]
    sanitized_filters['situations'] = situations

    sanitized_filters['production_lots'] = deduplicate_preserve_order(clean_list(payload.get('production_lots')))

    sanitized_filters['separation_stages'] = [
        code.lower()
        for code in deduplicate_preserve_order(clean_list(payload.get('separation_stages')))
        if code.lower() in VALID_SEPARATION_STAGE_CODES
    ]

    try:
        saved = save_user_parameters(user_id, LOAD_ROUTE_FILTERS_PARAM_NAME, json.dumps(sanitized_filters))
        if not saved:
            return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500
    except (TypeError, ValueError) as error:
        return jsonify({'success': False, 'message': f'Não foi possível processar os filtros: {error}'}), 400

    return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})


@app.route('/load_lots/route_planner_2/save_filters', methods=['POST'])
@login_required
def save_load_lot_route_filters_v2():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def clean_string(value):
        if value is None:
            return ''
        return str(value).strip()

    def clean_list(values, allow_blank=False):
        if not values:
            return []
        if isinstance(values, str):
            values_iterable = [values]
        else:
            try:
                values_iterable = list(values)
            except TypeError:
                values_iterable = []
        cleaned = []
        for value in values_iterable:
            text = clean_string(value)
            if text:
                cleaned.append(text)
            elif allow_blank:
                if value is None:
                    continue
                if isinstance(value, str):
                    if value.strip() == '':
                        cleaned.append('')
                elif text == '':
                    cleaned.append('')
        return cleaned

    def deduplicate_preserve_order(items):
        seen = set()
        result = []
        for item in items:
            if item not in seen:
                seen.add(item)
                result.append(item)
        return result

    sanitized_filters = {}

    start_date = clean_string(payload.get('start_date'))
    if start_date:
        try:
            datetime.datetime.strptime(start_date, '%Y-%m-%d')
        except ValueError:
            start_date = ''
    sanitized_filters['start_date'] = start_date

    end_date = clean_string(payload.get('end_date'))
    if end_date:
        try:
            datetime.datetime.strptime(end_date, '%Y-%m-%d')
        except ValueError:
            end_date = ''
    sanitized_filters['end_date'] = end_date

    allowed_missing_values = {'', 'yes', 'no'}
    missing_production_lot = clean_string(payload.get('missing_production_lot')).lower()
    if missing_production_lot not in allowed_missing_values:
        missing_production_lot = ''
    sanitized_filters['missing_production_lot'] = missing_production_lot

    allowed_status_codes = set(MAP_APPROVAL_STATUS_CODES)
    approval_statuses = [
        code.upper()
        for code in deduplicate_preserve_order(clean_list(payload.get('approval_statuses')))
        if code.upper() in allowed_status_codes
    ]
    sanitized_filters['approval_statuses'] = approval_statuses

    allowed_situation_codes = set(MAP_SITUATION_CODES)
    situations = [
        code.upper()
        for code in deduplicate_preserve_order(clean_list(payload.get('situations'), allow_blank=True))
        if code.upper() in allowed_situation_codes
    ]
    sanitized_filters['situations'] = situations

    sanitized_filters['production_lots'] = deduplicate_preserve_order(clean_list(payload.get('production_lots')))

    sanitized_filters['separation_stages'] = [
        code.lower()
        for code in deduplicate_preserve_order(clean_list(payload.get('separation_stages')))
        if code.lower() in VALID_SEPARATION_STAGE_CODES
    ]

    document_sources = clean_string(payload.get('document_sources')).lower()
    if document_sources not in MAP_DOCUMENT_SOURCE_RECORD_TYPES:
        document_sources = ''
    sanitized_filters['document_sources'] = document_sources

    try:
        saved = save_user_parameters(user_id, LOAD_ROUTE_FILTERS_PARAM_NAME_V2, json.dumps(sanitized_filters))
        if not saved:
            return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500
    except (TypeError, ValueError) as error:
        return jsonify({'success': False, 'message': f'Não foi possível processar os filtros: {error}'}), 400

    return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})


@app.route('/load_lots/<path:load_lot_code>')
@login_required
def load_lot_detail(load_lot_code):
    lot_code = (load_lot_code or '').strip()
    if not lot_code:
        flash('Lote inválido.', 'warning')
        return redirect(url_for('load_lots_view'))

    detail_orders, lot_info, detail_error = fetch_load_lot_orders(lot_code)
    if detail_error:
        flash(detail_error, 'danger')

    if not lot_info:
        flash('Lote não encontrado para consulta.', 'warning')
        return redirect(url_for('load_lots_view'))

    detail_totals = {
        'quantidade_total': sum(order['quantidade_total'] for order in detail_orders),
        'valor_total': sum(order['valor_total'] for order in detail_orders),
        'total_m3': lot_info.get('total_m3', 0.0),
    }

    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()
    back_params = {
        key: value
        for key, value in {
            'start_date': start_date_param,
            'end_date': end_date_param,
        }.items()
        if value
    }
    back_url = url_for('load_lots_view', **back_params)
    map_url = url_for('load_lot_map', load_lot_code=lot_code, **back_params)

    period_display = {
        'start': '',
        'end': '',
    }
    try:
        if start_date_param:
            period_display['start'] = datetime.datetime.strptime(start_date_param, '%Y-%m-%d').strftime('%d/%m/%Y')
        if end_date_param:
            period_display['end'] = datetime.datetime.strptime(end_date_param, '%Y-%m-%d').strftime('%d/%m/%Y')
    except ValueError:
        period_display = {'start': '', 'end': ''}

    return render_template(
        'load_lot_detail.html',
        page_title=f"Lote {lot_info['codigo']}",
        lot_info=lot_info,
        detail_orders=detail_orders,
        detail_totals=detail_totals,
        period_display=period_display,
        back_url=back_url,
        map_url=map_url,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/load_lots/<path:load_lot_code>/map')
@login_required
def load_lot_map(load_lot_code):
    lot_code = (load_lot_code or '').strip()
    if not lot_code:
        flash('Lote inválido.', 'warning')
        return redirect(url_for('load_lots_view'))

    detail_orders, lot_info, detail_error = fetch_load_lot_orders(lot_code)
    if detail_error:
        flash(detail_error, 'danger')

    if not lot_info:
        flash('Lote não encontrado para consulta.', 'warning')
        return redirect(url_for('load_lots_view'))

    ordered_stops = sorted(
        detail_orders,
        key=lambda order: route_sequence_sort_value(order.get('sequencia'))
    )

    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()
    nav_params = {
        key: value
        for key, value in {
            'start_date': start_date_param,
            'end_date': end_date_param,
        }.items()
        if value
    }

    detail_url = url_for('load_lot_detail', load_lot_code=lot_code, **nav_params)
    lots_url = url_for('load_lots_view', **nav_params)
    route_suggestion_url = url_for('load_lot_route_suggestion', load_lot_code=lot_code, **nav_params)
    route_map_url = url_for('load_lot_map', load_lot_code=lot_code, **nav_params)

    user_id = session.get('user_id')
    route_preferences = load_route_preferences_for_user(user_id)
    route_payload = build_route_payload_from_orders(ordered_stops)
    map_waypoints = build_map_waypoints(route_payload, route_preferences)

    return render_template(
        'load_lot_map.html',
        page_title=f"Mapa do Lote {lot_info['codigo']}",
        lot_info=lot_info,
        route_orders=ordered_stops,
        route_payload=route_payload,
        map_waypoints=map_waypoints,
        route_preferences=route_preferences,
        parameters_url=url_for('save_load_lot_map_parameters', load_lot_code=lot_code),
        detail_url=detail_url,
        lots_url=lots_url,
        route_suggestion_url=route_suggestion_url,
        route_map_url=route_map_url,
        is_suggestion_view=False,
        suggestion_meta={},
        nav_params=nav_params,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/load_lots/<path:load_lot_code>/map/suggestion')
@login_required
def load_lot_route_suggestion(load_lot_code):
    lot_code = (load_lot_code or '').strip()
    if not lot_code:
        flash('Lote inválido.', 'warning')
        return redirect(url_for('load_lots_view'))

    detail_orders, lot_info, detail_error = fetch_load_lot_orders(lot_code)
    if detail_error:
        flash(detail_error, 'danger')

    if not lot_info:
        flash('Lote não encontrado para consulta.', 'warning')
        return redirect(url_for('load_lots_view'))

    ordered_stops = sorted(
        detail_orders,
        key=lambda order: route_sequence_sort_value(order.get('sequencia'))
    )

    user_id = session.get('user_id')
    route_preferences = load_route_preferences_for_user(user_id)
    suggested_orders, suggestion_meta = generate_route_suggestion_orders(ordered_stops, route_preferences)

    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()
    nav_params = {
        key: value
        for key, value in {
            'start_date': start_date_param,
            'end_date': end_date_param,
        }.items()
        if value
    }

    detail_url = url_for('load_lot_detail', load_lot_code=lot_code, **nav_params)
    lots_url = url_for('load_lots_view', **nav_params)
    route_suggestion_url = url_for('load_lot_route_suggestion', load_lot_code=lot_code, **nav_params)
    route_map_url = url_for('load_lot_map', load_lot_code=lot_code, **nav_params)

    route_payload = build_route_payload_from_orders(suggested_orders, preferred_sequence_field='suggested_position')
    map_waypoints = build_map_waypoints(route_payload, route_preferences)

    return render_template(
        'load_lot_map.html',
        page_title=f"Sugestão de Rota {lot_info['codigo']}",
        lot_info=lot_info,
        route_orders=suggested_orders,
        route_payload=route_payload,
        map_waypoints=map_waypoints,
        route_preferences=route_preferences,
        parameters_url=url_for('save_load_lot_map_parameters', load_lot_code=lot_code),
        detail_url=detail_url,
        lots_url=lots_url,
        route_suggestion_url=route_suggestion_url,
        route_map_url=route_map_url,
        is_suggestion_view=True,
        suggestion_meta=suggestion_meta,
        nav_params=nav_params,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/load_lots/<path:load_lot_code>/map/parameters', methods=['POST'])
@login_required
def save_load_lot_map_parameters(load_lot_code):
    lot_code = (load_lot_code or '').strip()
    if not lot_code:
        flash('Lote inválido.', 'warning')
        return redirect(url_for('load_lots_view'))

    user_id = session.get('user_id')
    if not user_id:
        flash('Usuário não identificado para salvar parâmetros.', 'danger')
        return redirect(url_for('load_lot_map', load_lot_code=lot_code))

    def extract_pref(prefix):
        return {
            'enabled': request.form.get(f'{prefix}_enabled') == 'on',
            'cidade': (request.form.get(f'{prefix}_cidade') or '').strip(),
            'estado': (request.form.get(f'{prefix}_estado') or '').strip(),
        }

    preferences = {
        'start': extract_pref('start'),
        'end': extract_pref('end'),
    }

    param_name = LOAD_LOT_ROUTE_PARAM_NAME
    saved = save_user_parameters(user_id, param_name, json.dumps(preferences))
    if saved:
        flash('Preferências de rota salvas com sucesso.', 'success')
    else:
        flash('Não foi possível salvar as preferências de rota.', 'danger')

    redirect_params = {}
    for key in ('start_date', 'end_date'):
        value = (request.form.get(key) or '').strip()
        if value:
            redirect_params[key] = value

    return redirect(url_for('load_lot_map', load_lot_code=lot_code, **redirect_params))

@app.route('/sales_orders_list')
@login_required
def sales_orders_list():
    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    selected_cities = [value.strip() for value in request.args.getlist('cities') if value and value.strip()]
    selected_states = [value.strip() for value in request.args.getlist('states') if value and value.strip()]
    selected_vendors = [value.strip() for value in request.args.getlist('vendors') if value and value.strip()]
    selected_statuses = [
        value.strip().upper() for value in request.args.getlist('statuses') if value and value.strip()
    ]
    selected_situations = [
        value.strip().upper() for value in request.args.getlist('situations') if value and value.strip()
    ]
    selected_occurrences = [
        value.strip() for value in request.args.getlist('occurrences') if value and value.strip()
    ]
    selected_load_lot_flags = [
        value.strip().lower() for value in request.args.getlist('has_load_lot') if value and value.strip()
    ]
    selected_production_lot_flags = [
        value.strip().lower() for value in request.args.getlist('has_production_lot') if value and value.strip()
    ]

    filters = {
        'cities': selected_cities,
        'states': selected_states,
        'vendors': selected_vendors,
        'statuses': selected_statuses,
        'situations': selected_situations,
        'occurrences': selected_occurrences,
        'has_load_lot': selected_load_lot_flags,
        'has_production_lot': selected_production_lot_flags,
        'start_date': (request.args.get('start_date') or '').strip(),
        'end_date': (request.args.get('end_date') or '').strip(),
    }

    column_filters = {
        'filter_pedido': (request.args.get('filter_pedido') or '').strip(),
        'filter_data': (request.args.get('filter_data') or '').strip(),
        'filter_codigo': (request.args.get('filter_codigo') or '').strip(),
        'filter_cliente': (request.args.get('filter_cliente') or '').strip(),
        'filter_quantidade_total': (request.args.get('filter_quantidade_total') or '').strip(),
        'filter_valor_total': (request.args.get('filter_valor_total') or '').strip(),
        'filter_linha': (request.args.get('filter_linha') or '').strip(),
        'filter_approval_status': (request.args.get('filter_approval_status') or '').strip(),
        'filter_situation': (request.args.get('filter_situation') or '').strip(),
        'filter_occurrence': (request.args.get('filter_occurrence') or '').strip(),
        'filter_production_lots_display': (request.args.get('filter_production_lots_display') or '').strip(),
        'filter_load_lot': (request.args.get('filter_load_lot') or '').strip(),
    }

    filters.update(column_filters)

    if 'start_date' not in request.args and 'end_date' not in request.args:
        filters['start_date'] = first_day_of_month.strftime('%Y-%m-%d')
        filters['end_date'] = last_day_of_month.strftime('%Y-%m-%d')

    orders, error_message = fetch_sales_orders(filters)

    if error_message:
        flash(error_message, 'danger')

    totals = {
        'quantidade_total': sum(order['quantidade_total'] for order in orders),
        'valor_total': sum(order['valor_total'] for order in orders),
    }

    load_lot_filter_options = [
        {'value': 'yes', 'label': 'Sim'},
        {'value': 'no', 'label': 'Não'},
    ]
    production_lot_filter_options = [
        {'value': 'yes', 'label': 'Sim'},
        {'value': 'no', 'label': 'Não'},
    ]

    return render_template(
        'sales_orders_list.html',
        page_title="Pedidos de Vendas",
        orders=orders,
        totals=totals,
        filters=filters,
        city_options=get_distinct_cities(),
        state_options=get_distinct_states(),
        vendor_options=get_sales_order_vendors(),
        occurrence_options=get_distinct_occurrences(),
        approval_status_options=ORDER_APPROVAL_STATUS_OPTIONS,
        situation_options=ORDER_SITUATION_OPTIONS,
        load_lot_filter_options=load_lot_filter_options,
        production_lot_filter_options=production_lot_filter_options,
        occurrence_blank_value=OCCURRENCE_BLANK_VALUE,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


def render_technical_assistance_list_page(list_endpoint_name, page_title, list_heading=None):
    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except ValueError:
            return None

    start_date = parse_date(start_date_param)
    end_date = parse_date(end_date_param)

    if start_date_param and start_date is None:
        flash('Data inicial inválida. Ajuste o filtro e tente novamente.', 'warning')
        start_date_param = ''
    if end_date_param and end_date is None:
        flash('Data final inválida. Ajuste o filtro e tente novamente.', 'warning')
        end_date_param = ''

    if not start_date_param and not end_date_param:
        start_date_param = first_day_of_month.strftime('%Y-%m-%d')
        end_date_param = last_day_of_month.strftime('%Y-%m-%d')
        start_date = first_day_of_month
        end_date = last_day_of_month

    selected_statuses = [
        normalize_lookup_code(value)
        for value in request.args.getlist('statuses')
        if value is not None
    ]
    selected_statuses = list(dict.fromkeys(selected_statuses))

    selected_situations = [
        normalize_lookup_code(value)
        for value in request.args.getlist('situations')
        if value is not None
    ]
    selected_situations = list(dict.fromkeys(selected_situations))

    selected_load_lots = [
        (value or '').strip()
        for value in request.args.getlist('load_lots')
        if value is not None
    ]
    selected_load_lots = [value for value in selected_load_lots if value]
    selected_load_lots = list(dict.fromkeys(selected_load_lots))

    selected_production_lots = [
        (value or '').strip()
        for value in request.args.getlist('production_lots')
        if value is not None
    ]
    selected_production_lots = [value for value in selected_production_lots if value]
    selected_production_lots = list(dict.fromkeys(selected_production_lots))

    selected_lines = [
        (value or '').strip().upper()
        for value in request.args.getlist('lines')
        if value is not None
    ]
    selected_lines = [value for value in selected_lines if value]
    selected_lines = list(dict.fromkeys(selected_lines))

    assistance_code = (request.args.get('assistance_code') or '').strip()
    customer_filter = (request.args.get('customer') or '').strip()
    representative_filter = (request.args.get('representative') or '').strip()
    responsavel_filter = (request.args.get('responsavel') or '').strip()

    requested_sort_by = (request.args.get('sort_by') or 'assdata').strip()
    sort_order = (request.args.get('sort_order') or 'desc').strip().lower()
    if sort_order not in ['asc', 'desc']:
        sort_order = 'desc'

    extra_sort_fields = {'reservado', 'separado', 'carregado', 'linha'}
    sort_by_for_query = requested_sort_by
    if requested_sort_by in extra_sort_fields:
        sort_by_for_query = 'assdata'

    filters = {
        'start_date': start_date,
        'end_date': end_date,
        'statuses': selected_statuses,
        'situations': selected_situations,
        'load_lots': selected_load_lots,
        'production_lots': selected_production_lots,
        'lines': selected_lines,
        'assistance_code': assistance_code,
        'customer': customer_filter,
        'representative': representative_filter,
        'responsavel': responsavel_filter,
        'sort_by': sort_by_for_query,
        'sort_order': sort_order,
    }

    assistance_records, error_message = fetch_technical_assistance(filters)
    if error_message:
        flash(error_message, 'danger')

    if requested_sort_by in extra_sort_fields:
        reverse = sort_order == 'desc'
        if requested_sort_by == 'linha':
            assistance_records.sort(
                key=lambda record: (record.get('linha') or '').strip().upper(),
                reverse=reverse,
            )
        else:
            assistance_records.sort(
                key=lambda record: record.get(requested_sort_by) or Decimal('0'),
                reverse=reverse,
            )

    total_pecas = Decimal('0')
    valor_total = Decimal('0')
    for record in assistance_records:
        quantidade = record.get('quantidade_pecas')
        if isinstance(quantidade, Decimal):
            total_pecas += quantidade
        elif quantidade is not None:
            try:
                total_pecas += Decimal(quantidade)
            except (TypeError, InvalidOperation):
                pass

        valor = record.get('valor_total')
        if isinstance(valor, Decimal):
            valor_total += valor
        elif valor is not None:
            try:
                valor_total += Decimal(valor)
            except (TypeError, InvalidOperation):
                pass

    totals = {
        'total_registros': len(assistance_records),
        'total_pecas': total_pecas,
        'valor_total': valor_total,
    }

    status_options = get_technical_assistance_status_options()
    situation_options = get_technical_assistance_situation_options()

    def _normalize_lot_options(raw_options):
        cleaned = []
        seen = set()
        for option in raw_options or []:
            code = (option.get('code') or '').strip()
            description = (option.get('description') or '').strip()
            if not code:
                continue
            key = (code, description)
            if key in seen:
                continue
            seen.add(key)
            cleaned.append({'code': code, 'description': description})
        return cleaned

    load_lot_options = _normalize_lot_options(get_distinct_load_lots())
    production_lot_options = _normalize_lot_options(get_distinct_production_lots())

    line_options = []
    seen_lines = set()
    for line_name in get_distinct_product_lines():
        code = (line_name or '').strip().upper()
        if not code or code in seen_lines:
            continue
        seen_lines.add(code)
        line_options.append({'code': code, 'label': code})

    active_filters = {
        'start_date': start_date_param,
        'end_date': end_date_param,
        'statuses': selected_statuses,
        'situations': selected_situations,
        'load_lots': selected_load_lots,
        'production_lots': selected_production_lots,
        'lines': selected_lines,
        'assistance_code': assistance_code,
        'customer': customer_filter,
        'representative': representative_filter,
        'responsavel': responsavel_filter,
    }

    return render_template(
        'technical_assistance_list.html',
        page_title=page_title,
        assistance_records=assistance_records,
        totals=totals,
        status_options=status_options,
        situation_options=situation_options,
        load_lot_options=load_lot_options,
        production_lot_options=production_lot_options,
        line_options=line_options,
        filters=active_filters,
        sort_by=requested_sort_by,
        sort_order=sort_order,
        list_url=url_for(list_endpoint_name),
        list_heading=list_heading or page_title,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


def render_production_assistance_list_page(list_endpoint_name, page_title, list_heading=None):
    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    start_date_param = (request.args.get('start_date') or '').strip()
    end_date_param = (request.args.get('end_date') or '').strip()

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except ValueError:
            return None

    start_date = parse_date(start_date_param)
    end_date = parse_date(end_date_param)

    if start_date_param and start_date is None:
        flash('Data inicial inválida. Ajuste o filtro e tente novamente.', 'warning')
        start_date_param = ''
    if end_date_param and end_date is None:
        flash('Data final inválida. Ajuste o filtro e tente novamente.', 'warning')
        end_date_param = ''

    if not start_date_param and not end_date_param:
        start_date_param = first_day_of_month.strftime('%Y-%m-%d')
        end_date_param = last_day_of_month.strftime('%Y-%m-%d')
        start_date = first_day_of_month
        end_date = last_day_of_month

    selected_statuses = [
        normalize_lookup_code(value)
        for value in request.args.getlist('statuses')
        if value is not None
    ]
    selected_statuses = list(dict.fromkeys(selected_statuses))

    selected_situations = [
        normalize_lookup_code(value)
        for value in request.args.getlist('situations')
        if value is not None
    ]
    selected_situations = list(dict.fromkeys(selected_situations))

    selected_load_lots = [
        (value or '').strip()
        for value in request.args.getlist('load_lots')
        if value is not None
    ]
    selected_load_lots = [value for value in selected_load_lots if value]
    selected_load_lots = list(dict.fromkeys(selected_load_lots))

    selected_production_lots = [
        (value or '').strip()
        for value in request.args.getlist('production_lots')
        if value is not None
    ]
    selected_production_lots = [value for value in selected_production_lots if value]
    selected_production_lots = list(dict.fromkeys(selected_production_lots))

    selected_lines = [
        (value or '').strip().upper()
        for value in request.args.getlist('lines')
        if value is not None
    ]
    selected_lines = [value for value in selected_lines if value]
    selected_lines = list(dict.fromkeys(selected_lines))

    assistance_code = (request.args.get('assistance_code') or '').strip()
    customer_filter = (request.args.get('customer') or '').strip()
    representative_filter = (request.args.get('representative') or '').strip()
    responsavel_filter = (request.args.get('responsavel') or '').strip()

    requested_sort_by = (request.args.get('sort_by') or 'assdata').strip()
    sort_order = (request.args.get('sort_order') or 'desc').strip().lower()
    if sort_order not in ['asc', 'desc']:
        sort_order = 'desc'

    extra_sort_fields = {'reservado', 'separado', 'carregado', 'linha'}
    sort_by_for_query = requested_sort_by
    if requested_sort_by in extra_sort_fields:
        sort_by_for_query = 'assdata'

    filters = {
        'start_date': start_date,
        'end_date': end_date,
        'statuses': selected_statuses,
        'situations': selected_situations,
        'load_lots': selected_load_lots,
        'production_lots': selected_production_lots,
        'lines': selected_lines,
        'assistance_code': assistance_code,
        'customer': customer_filter,
        'representative': representative_filter,
        'responsavel': responsavel_filter,
        'sort_by': sort_by_for_query,
        'sort_order': sort_order,
    }

    assistance_records, error_message = fetch_technical_assistance(filters)
    if error_message:
        flash(error_message, 'danger')

    if requested_sort_by in extra_sort_fields:
        reverse = sort_order == 'desc'
        if requested_sort_by == 'linha':
            assistance_records.sort(
                key=lambda record: (record.get('linha') or '').strip().upper(),
                reverse=reverse,
            )
        else:
            assistance_records.sort(
                key=lambda record: record.get(requested_sort_by) or Decimal('0'),
                reverse=reverse,
            )

    total_pecas = Decimal('0')
    valor_total = Decimal('0')
    for record in assistance_records:
        quantidade = record.get('quantidade_pecas')
        if isinstance(quantidade, Decimal):
            total_pecas += quantidade
        elif quantidade is not None:
            try:
                total_pecas += Decimal(quantidade)
            except (TypeError, InvalidOperation):
                pass

        valor = record.get('valor_total')
        if isinstance(valor, Decimal):
            valor_total += valor
        elif valor is not None:
            try:
                valor_total += Decimal(valor)
            except (TypeError, InvalidOperation):
                pass

    totals = {
        'total_registros': len(assistance_records),
        'total_pecas': total_pecas,
        'valor_total': valor_total,
    }

    status_options = get_technical_assistance_status_options()
    situation_options = get_technical_assistance_situation_options()

    def _normalize_lot_options(raw_options):
        cleaned = []
        seen = set()
        for option in raw_options or []:
            code = (option.get('code') or '').strip()
            description = (option.get('description') or '').strip()
            if not code:
                continue
            key = (code, description)
            if key in seen:
                continue
            seen.add(key)
            cleaned.append({'code': code, 'description': description})
        return cleaned

    load_lot_options = _normalize_lot_options(get_distinct_load_lots())
    production_lot_options = _normalize_lot_options(get_distinct_production_lots())

    line_options = []
    seen_lines = set()
    for line_name in get_distinct_product_lines():
        code = (line_name or '').strip().upper()
        if not code or code in seen_lines:
            continue
        seen_lines.add(code)
        line_options.append({'code': code, 'label': code})

    active_filters = {
        'start_date': start_date_param,
        'end_date': end_date_param,
        'statuses': selected_statuses,
        'situations': selected_situations,
        'load_lots': selected_load_lots,
        'production_lots': selected_production_lots,
        'lines': selected_lines,
        'assistance_code': assistance_code,
        'customer': customer_filter,
        'representative': representative_filter,
        'responsavel': responsavel_filter,
    }

    return render_template(
        'production_assistance_list.html',
        page_title=page_title,
        assistance_records=assistance_records,
        totals=totals,
        status_options=status_options,
        situation_options=situation_options,
        load_lot_options=load_lot_options,
        production_lot_options=production_lot_options,
        line_options=line_options,
        filters=active_filters,
        sort_by=requested_sort_by,
        sort_order=sort_order,
        list_url=url_for(list_endpoint_name),
        list_heading=list_heading or page_title,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/technical_assistance_list')
@login_required
def technical_assistance_list():
    return render_technical_assistance_list_page(
        'technical_assistance_list',
        "Assistência Técnica"
    )


@app.route('/production_assistance_list')
@login_required
def production_assistance_list():
    return render_production_assistance_list_page(
        'production_assistance_list',
        "Consultar Assistências"
    )


@app.route('/technical_assistance/<path:assistance_identifier>/details')
@login_required
def technical_assistance_details(assistance_identifier):
    details, error = fetch_technical_assistance_details(assistance_identifier)
    if error:
        status_code = error.get('status', 500)
        return jsonify({'error': error.get('message', 'Erro ao carregar detalhes da assistência.')}), status_code
    return jsonify(details)


@app.route('/technical_assistance/<path:assistance_identifier>/media')
@login_required
def technical_assistance_media(assistance_identifier):
    """
    Retorna a lista de mídias disponíveis para a assistência selecionada.
    """
    _, assistance_dir, error = resolve_assistance_media_directory(assistance_identifier)
    if error:
        return jsonify({'error': error}), 400

    if not assistance_dir.exists() or not assistance_dir.is_dir():
        return jsonify({'files': []})

    files_payload = build_assistance_media_payload(assistance_dir, assistance_identifier)
    return jsonify({'files': files_payload})


@app.route('/technical_assistance/<path:assistance_identifier>/media/file')
@login_required
def technical_assistance_media_file(assistance_identifier):
    """
    Fornece o conteúdo do arquivo selecionado para a assistência.
    """
    token = request.args.get('token', '').strip()
    if not token:
        abort(404)

    _, assistance_dir, error = resolve_assistance_media_directory(assistance_identifier)
    if error or not assistance_dir:
        abort(404)

    file_name = _decode_media_token(token)
    if not file_name:
        abort(404)

    file_path = (assistance_dir / file_name)
    try:
        file_path = file_path.resolve(strict=False)
    except (RuntimeError, OSError):
        abort(404)

    if not _is_subpath(file_path, assistance_dir) or not file_path.is_file():
        abort(404)

    media_kind = _get_media_kind_from_extension(file_path.suffix)
    if not media_kind:
        abort(404)

    mimetype = mimetypes.guess_type(file_path.name)[0] or 'application/octet-stream'
    # conditional=True habilita suporte a Range Requests para vídeos.
    return send_file(file_path, mimetype=mimetype, as_attachment=False, conditional=True)


@app.route('/production_assistance/<path:assistance_identifier>/details')
@login_required
def production_assistance_details(assistance_identifier):
    details, error = fetch_production_assistance_details(assistance_identifier)
    if error:
        status_code = error.get('status', 500)
        return jsonify({'error': error.get('message', 'Erro ao carregar detalhes da assistência.')}), status_code
    return jsonify(details)


@app.route('/sales_returns_list')
@login_required
def sales_returns_list():
    return render_template('placeholder.html', page_title="Lista de Devoluções de Venda", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Financeiro) ---
@app.route('/accounts_receivable_list')
@login_required
def accounts_receivable_list():
    return render_template('placeholder.html', page_title="Contas a Receber", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/accounts_payable_list')
@login_required
def accounts_payable_list():
    return render_template('placeholder.html', page_title="Contas a Pagar", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/titles_list')
@login_required
def titles_list():
    return render_template('placeholder.html', page_title="Lista de Títulos", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/checks_list')
@login_required
def checks_list():
    return render_template('placeholder.html', page_title="Cheques Pré-Datados", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Estoque) ---
@app.route('/stock_movements_list')
@login_required
def stock_movements_list():
    return render_template('placeholder.html', page_title="Movimentações de Estoque", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/product_batches_list')
@login_required
def product_batches_list():
    return render_template('placeholder.html', page_title="Lotes de Produto", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Relatórios) ---
@app.route('/report_revenue_by_cfop')
@login_required
def report_revenue_by_cfop():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_cfop(filters)
    totals = {
        'valor_bruto': sum(row['valor_bruto'] for row in data),
        'valor_ipi': sum(row['valor_ipi'] for row in data),
        'valor_st': sum(row['valor_st'] for row in data),
        'valor_liquido': sum(row['valor_liquido'] for row in data)
    }
    return render_template(
        'report_revenue_by_cfop.html',
        data=data,
        filters=filters,
        totals=totals,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_sales_by_product')
@login_required
def report_sales_by_product():
    return render_template(
        'placeholder.html',
        page_title="Relatório: Vendas por Produto",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_customer_sales')
@login_required
def report_customer_sales():
    return render_template(
        'placeholder.html',
        page_title="Relatório: Vendas por Cliente",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_state')
@login_required
def report_revenue_by_state():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'start_date': request.args.get('start_date'),
        'end_date': request.args.get('end_date'),
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_state(filters)
    chart_labels = [row['state'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_state.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_line')
@login_required
def report_revenue_by_line():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_line(filters)
    chart_labels = [row['line'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_line.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_average_price')
@login_required
def report_average_price():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    chart_labels, chart_datasets, treemap_data, line_colors = fetch_average_price(filters)
    return render_template(
        'report_average_price.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_datasets=chart_datasets,
        treemap_data=treemap_data,
        line_colors=line_colors,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_day')
@login_required
def report_revenue_by_day():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.getlist('state'),
        'city': request.args.getlist('city'),
        'vendor': request.args.getlist('vendor'),
        'line': request.args.getlist('line')
    }
    data = fetch_revenue_by_day(filters)
    chart_labels = [row['day'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    months_selected = set()
    if filters['month']:
        for m in filters['month']:
            try:
                months_selected.add(int(m))
            except ValueError:
                continue
    else:
        months_selected = set(range(1, 13))
    business_days = count_business_days(current_year, months_selected)
    daily_average = total_liquido / business_days if business_days else 0
    return render_template(
        'report_revenue_by_day.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        daily_average=daily_average,
        states=get_distinct_states(),
        cities=get_distinct_cities(),
        vendors=get_distinct_vendors(),
        product_lines=get_distinct_product_lines(),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_vendor')
@login_required
def report_revenue_by_vendor():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_vendor(filters)
    chart_labels = [row['vendor'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_vendor.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/commercial_reports')
@login_required
def commercial_reports():
    """Página de seleção dos relatórios comerciais."""
    return render_template(
        'commercial_reports.html',
        page_title="Relatórios Comerciais",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_sales_orders_comparison')
@login_required
def report_sales_orders_comparison():
    """Exibe o comparativo mensal de pedidos de venda entre dois anos consecutivos."""
    current_year = datetime.date.today().year
    requested_year = (request.args.get('year') or '').strip()
    filter_applied_flag = (request.args.get('filter_applied') or '').strip() == '1'
    ignore_saved_flag = (request.args.get('ignore_saved') or '').strip() == '1'
    user_id = session.get('user_id')

    saved_filters = {}
    if user_id:
        saved_filters_raw = get_user_parameters(user_id, REPORT_SALES_COMPARISON_FILTERS_PARAM)
        if saved_filters_raw:
            try:
                saved_filters = json.loads(saved_filters_raw) or {}
            except (TypeError, ValueError):
                saved_filters = {}

    if requested_year:
        try:
            current_year = int(requested_year)
        except (TypeError, ValueError):
            current_year = datetime.date.today().year
    elif not ignore_saved_flag:
        saved_year = saved_filters.get('year')
        if saved_year is not None:
            try:
                current_year = int(saved_year)
            except (TypeError, ValueError):
                current_year = datetime.date.today().year

    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'vendor': request.args.getlist('vendor'),
        'state': request.args.getlist('state'),
        'status': request.args.getlist('status'),
        'situation': request.args.getlist('situation'),
        'line': request.args.getlist('line'),
        'customer': request.args.getlist('customer'),
        'transaction': request.args.getlist('transaction'),
    }

    use_saved_defaults = bool(saved_filters) and not filter_applied_flag and not ignore_saved_flag
    if use_saved_defaults:
        list_keys = ['month', 'vendor', 'state', 'status', 'situation', 'line', 'customer', 'transaction']
        allow_blank_keys = {'situation'}
        for key in list_keys:
            if filters.get(key):
                continue
            saved_value = saved_filters.get(key)
            if not saved_value:
                continue
            if isinstance(saved_value, list):
                cleaned = []
                for item in saved_value:
                    if item is None:
                        continue
                    text = str(item).strip()
                    if text or key in allow_blank_keys:
                        cleaned.append(text)
                if cleaned:
                    filters[key] = cleaned
            else:
                text = str(saved_value).strip()
                if text or key in allow_blank_keys:
                    filters[key] = [text]

    months_selected = []
    for month in filters['month']:
        try:
            month_int = int(month)
        except (TypeError, ValueError):
            continue
        if 1 <= month_int <= 12:
            months_selected.append(month_int)
    if not months_selected:
        months_selected = list(range(1, 13))
    else:
        months_selected = sorted(set(months_selected))

    current_data_all = fetch_monthly_sales_orders(current_year, filters)
    prev_year = current_year - 1
    previous_data_all = fetch_monthly_sales_orders(prev_year, filters)

    chart_labels = [f"{str(m).zfill(2)}/{current_year}" for m in months_selected]
    current_data = [current_data_all[m - 1] for m in months_selected]
    previous_data = [previous_data_all[m - 1] for m in months_selected]

    current_total = sum(current_data)
    previous_total = sum(previous_data)
    totals = {
        'current_total': current_total,
        'current_average': current_total / len(months_selected) if months_selected else 0,
        'previous_total': previous_total,
        'previous_average': previous_total / len(months_selected) if months_selected else 0,
        'variation_percent': ((current_total - previous_total) / previous_total * 100) if previous_total else 0,
    }

    vendor_options = get_sales_order_vendors()
    vendor_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '') for opt in vendor_options}
    customer_options = get_sales_order_customers()
    customer_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '') for opt in customer_options}
    status_options = ORDER_APPROVAL_STATUS_OPTIONS
    status_label_map = {opt['code']: opt['label'] for opt in status_options}
    situation_options = ORDER_SITUATION_OPTIONS
    situation_label_map = {opt['code']: opt['label'] for opt in situation_options}
    line_options = get_distinct_product_lines()
    transaction_options = get_sales_order_transactions()
    transaction_label_map = {(opt.get('code') or '').strip(): (opt.get('label') or '') for opt in transaction_options}

    selected_vendor_labels = []
    for code in filters['vendor']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = vendor_label_map.get(normalized, '')
        if name and normalized:
            label = f"{name} ({normalized})"
        elif name:
            label = name
        else:
            label = normalized
        if label not in selected_vendor_labels:
            selected_vendor_labels.append(label)

    selected_state_labels = list(dict.fromkeys(filters['state'])) if filters['state'] else []

    selected_status_labels = []
    for code in filters['status']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = status_label_map.get(normalized, normalized)
        if label not in selected_status_labels:
            selected_status_labels.append(label)

    selected_situation_labels = []
    for code in filters['situation']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = situation_label_map.get(normalized, normalized)
        if label not in selected_situation_labels:
            selected_situation_labels.append(label)

    selected_line_labels = []
    for name in filters['line']:
        label = (name or '').strip()
        if not label:
            continue
        if label not in selected_line_labels:
            selected_line_labels.append(label)

    selected_customer_labels = []
    for code in filters['customer']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = customer_label_map.get(normalized, '')
        if name and normalized:
            label = f"{name} ({normalized})"
        elif name:
            label = name
        else:
            label = normalized
        if label not in selected_customer_labels:
            selected_customer_labels.append(label)

    selected_transaction_labels = []
    for code in filters['transaction']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = transaction_label_map.get(normalized, '')
        if name and normalized:
            label = f"{name} ({normalized})"
        elif name:
            label = name
        else:
            label = normalized
        if label not in selected_transaction_labels:
            selected_transaction_labels.append(label)

    return render_template(
        'report_sales_orders_comparison.html',
        chart_labels=chart_labels,
        current_year_data=current_data,
        previous_year_data=previous_data,
        current_year_label=str(current_year),
        previous_year_label=str(prev_year),
        totals=totals,
        filters=filters,
        vendor_options=vendor_options,
        status_options=status_options,
        situation_options=situation_options,
        line_options=line_options,
        customer_options=customer_options,
        transaction_options=transaction_options,
        selected_vendor_labels=selected_vendor_labels,
        selected_state_labels=selected_state_labels,
        selected_status_labels=selected_status_labels,
        selected_situation_labels=selected_situation_labels,
        selected_line_labels=selected_line_labels,
        selected_customer_labels=selected_customer_labels,
        selected_transaction_labels=selected_transaction_labels,
        state_options=get_distinct_states(),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_orders_by_representatives')
@login_required
def report_orders_by_representatives():
    def normalize_values(values, allow_blank=False, uppercase=False):
        normalized = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if not text and not allow_blank:
                continue
            if uppercase and text:
                text = text.upper()
            normalized.append(text)
        return normalized

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return None

    today = datetime.date.today()
    current_first_day = today.replace(day=1)
    current_last_day = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    user_id = session.get('user_id')
    saved_filters = {}
    if user_id:
        saved_filters_raw = get_user_parameters(user_id, REPORT_ORDERS_REP_FILTERS_PARAM)
        if saved_filters_raw:
            try:
                saved_filters = json.loads(saved_filters_raw) or {}
            except (TypeError, ValueError):
                saved_filters = {}

    filter_applied_flag = bool(request.args.get('filter_applied'))
    ignore_saved_flag = (request.args.get('ignore_saved') or '').strip() == '1'
    use_saved_defaults = bool(saved_filters) and not filter_applied_flag and not ignore_saved_flag

    def saved_list(key):
        value = saved_filters.get(key)
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    start_date_raw = (request.args.get('start_date') or '').strip()
    end_date_raw = (request.args.get('end_date') or '').strip()

    if use_saved_defaults:
        if not start_date_raw:
            start_date_raw = str(saved_filters.get('start_date') or '').strip()
        if not end_date_raw:
            end_date_raw = str(saved_filters.get('end_date') or '').strip()

    vendor_values = normalize_values(request.args.getlist('vendor'))
    if use_saved_defaults and not vendor_values:
        vendor_values = normalize_values(saved_list('vendor'))

    state_values = normalize_values(request.args.getlist('state'), uppercase=True)
    if use_saved_defaults and not state_values:
        state_values = normalize_values(saved_list('state'), uppercase=True)

    customer_values = normalize_values(request.args.getlist('customer'))
    if use_saved_defaults and not customer_values:
        customer_values = normalize_values(saved_list('customer'))

    line_values = normalize_values(request.args.getlist('line'), uppercase=True)
    if use_saved_defaults and not line_values:
        line_values = normalize_values(saved_list('line'), uppercase=True)

    status_values = normalize_values(request.args.getlist('status'), uppercase=True)
    if use_saved_defaults and not status_values:
        status_values = normalize_values(saved_list('status'), uppercase=True)

    situation_values = normalize_values(request.args.getlist('situation'), allow_blank=True, uppercase=True)
    if use_saved_defaults and not situation_values:
        situation_values = normalize_values(saved_list('situation'), allow_blank=True, uppercase=True)

    transaction_values = normalize_values(request.args.getlist('transaction'))
    if use_saved_defaults and not transaction_values:
        transaction_values = normalize_values(saved_list('transaction'))

    if not start_date_raw:
        start_date_raw = current_first_day.strftime('%Y-%m-%d')
    if not end_date_raw:
        end_date_raw = current_last_day.strftime('%Y-%m-%d')

    start_date_obj = parse_date(start_date_raw)
    end_date_obj = parse_date(end_date_raw)

    filters_template = {
        'start_date': start_date_raw,
        'end_date': end_date_raw,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }
    query_filters = {
        'start_date': start_date_obj,
        'end_date': end_date_obj,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    data = fetch_orders_by_representative(query_filters)
    chart_labels = [row['representative'] for row in data]
    chart_values = [row['total'] for row in data]
    total_value = sum(chart_values)

    vendor_options = get_sales_order_vendors()
    vendor_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in vendor_options}
    customer_options = get_sales_order_customers()
    customer_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in customer_options}
    transaction_options = get_sales_order_transactions()
    transaction_label_map = {(opt.get('code') or '').strip(): (opt.get('label') or '').strip() for opt in transaction_options}
    status_options = ORDER_APPROVAL_STATUS_OPTIONS
    status_label_map = ORDER_APPROVAL_STATUS_LABELS
    situation_options = ORDER_SITUATION_OPTIONS
    situation_label_map = ORDER_SITUATION_LABELS

    selected_vendor_labels = []
    for code in filters_template['vendor']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = vendor_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_vendor_labels:
            selected_vendor_labels.append(label)

    selected_state_labels = []
    for state in filters_template['state']:
        label = (state or '').strip()
        if not label:
            continue
        if label not in selected_state_labels:
            selected_state_labels.append(label)

    selected_status_labels = []
    for code in filters_template['status']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = status_label_map.get(normalized, normalized)
        if label not in selected_status_labels:
            selected_status_labels.append(label)

    selected_situation_labels = []
    for code in filters_template['situation']:
        normalized = (code or '').strip().upper()
        if normalized or code == '':
            label = situation_label_map.get(normalized, normalized)
            if label not in selected_situation_labels:
                selected_situation_labels.append(label)

    selected_line_labels = []
    for line in filters_template['line']:
        label = (line or '').strip()
        if not label:
            continue
        if label not in selected_line_labels:
            selected_line_labels.append(label)

    selected_customer_labels = []
    for code in filters_template['customer']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = customer_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_customer_labels:
            selected_customer_labels.append(label)

    selected_transaction_labels = []
    for code in filters_template['transaction']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = transaction_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_transaction_labels:
            selected_transaction_labels.append(label)

    def format_date_label(date_str):
        if not date_str:
            return ''
        try:
            return datetime.datetime.strptime(date_str, '%Y-%m-%d').strftime('%d/%m/%Y')
        except (ValueError, TypeError):
            return date_str

    start_label = format_date_label(start_date_raw)
    end_label = format_date_label(end_date_raw)
    period_label = ''
    if start_label and end_label:
        period_label = f"{start_label} → {end_label}"
    elif start_label:
        period_label = f"A partir de {start_label}"
    elif end_label:
        period_label = f"Até {end_label}"

    return render_template(
        'report_orders_by_representatives.html',
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_value=total_value,
        filters=filters_template,
        period_label=period_label,
        vendor_options=vendor_options,
        customer_options=customer_options,
        transaction_options=transaction_options,
        status_options=status_options,
        situation_options=situation_options,
        line_options=get_distinct_product_lines(),
        state_options=get_distinct_states(),
        selected_vendor_labels=selected_vendor_labels,
        selected_state_labels=selected_state_labels,
        selected_status_labels=selected_status_labels,
        selected_situation_labels=selected_situation_labels,
        selected_line_labels=selected_line_labels,
        selected_customer_labels=selected_customer_labels,
        selected_transaction_labels=selected_transaction_labels,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_orders_by_representatives/save_filters', methods=['POST'])
@login_required
def save_report_orders_by_representatives_filters():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    def deduplicate_preserve_order(values):
        seen = set()
        ordered = []
        for value in values:
            if value in seen:
                continue
            seen.add(value)
            ordered.append(value)
        return ordered

    def sanitize_multi(field_name, uppercase=False, allow_blank=False):
        values = ensure_list(payload.get(field_name))
        cleaned = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if not text and not allow_blank:
                continue
            if uppercase and text:
                text = text.upper()
            cleaned.append(text)
        return deduplicate_preserve_order(cleaned)

    def sanitize_date(value):
        if not value:
            return ''
        text = str(value).strip()
        try:
            parsed = datetime.datetime.strptime(text, '%Y-%m-%d').date()
            return parsed.strftime('%Y-%m-%d')
        except (ValueError, TypeError):
            return ''

    sanitized_filters = {
        'start_date': sanitize_date(payload.get('start_date')),
        'end_date': sanitize_date(payload.get('end_date')),
        'vendor': sanitize_multi('vendor'),
        'state': sanitize_multi('state', uppercase=True),
        'customer': sanitize_multi('customer'),
        'line': sanitize_multi('line', uppercase=True),
        'status': sanitize_multi('status', uppercase=True),
        'situation': sanitize_multi('situation', uppercase=True, allow_blank=True),
        'transaction': sanitize_multi('transaction'),
    }

    try:
        saved = save_user_parameters(user_id, REPORT_ORDERS_REP_FILTERS_PARAM, json.dumps(sanitized_filters))
        if not saved:
            raise RuntimeError('Não foi possível salvar os filtros.')
        return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})
    except Exception as err:
        print(f'Erro ao salvar filtros de Pedidos por Representantes: {err}')
        return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500


@app.route('/report_orders_by_state')
@login_required
def report_orders_by_state():
    def normalize_values(values, allow_blank=False, uppercase=False):
        normalized = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if not text and not allow_blank:
                continue
            if uppercase and text:
                text = text.upper()
            normalized.append(text)
        return normalized

    def normalize_saved_values(value, allow_blank=False, uppercase=False):
        if value is None:
            return []
        source = value if isinstance(value, list) else [value]
        return normalize_values(source, allow_blank=allow_blank, uppercase=uppercase)

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return None

    filter_applied_flag = (request.args.get('filter_applied') or '').strip() == '1'
    ignore_saved_flag = (request.args.get('ignore_saved') or '').strip() == '1'
    user_id = session.get('user_id')

    saved_filters = {}
    if user_id:
        saved_raw = get_user_parameters(user_id, REPORT_ORDERS_BY_STATE_FILTERS_PARAM)
        if saved_raw:
            try:
                saved_filters = json.loads(saved_raw) or {}
            except (TypeError, ValueError):
                saved_filters = {}

    today = datetime.date.today()
    first_day = today.replace(day=1)
    last_day = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    start_date_raw = (request.args.get('start_date') or '').strip()
    end_date_raw = (request.args.get('end_date') or '').strip()
    start_date_obj = parse_date(start_date_raw)
    end_date_obj = parse_date(end_date_raw)

    vendor_values = normalize_values(request.args.getlist('vendor'))
    state_values = normalize_values(request.args.getlist('state'), uppercase=True)
    customer_values = normalize_values(request.args.getlist('customer'))
    line_values = normalize_values(request.args.getlist('line'), uppercase=True)
    status_values = normalize_values(request.args.getlist('status'), uppercase=True)
    situation_values = normalize_values(request.args.getlist('situation'), allow_blank=True, uppercase=True)
    transaction_values = normalize_values(request.args.getlist('transaction'))

    filters_template = {
        'start_date': start_date_raw,
        'end_date': end_date_raw,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    use_saved_defaults = bool(saved_filters) and not filter_applied_flag and not ignore_saved_flag
    if use_saved_defaults:
        multi_fields = [
            ('vendor', False, False),
            ('state', True, False),
            ('customer', False, False),
            ('line', True, False),
            ('status', True, False),
            ('situation', True, True),
            ('transaction', False, False),
        ]
        for key, uppercase, allow_blank in multi_fields:
            if filters_template.get(key):
                continue
            saved_value = saved_filters.get(key)
            restored = normalize_saved_values(saved_value, uppercase=uppercase, allow_blank=allow_blank)
            if restored:
                filters_template[key] = restored
        if not filters_template['start_date']:
            saved_start = saved_filters.get('start_date')
            if saved_start:
                filters_template['start_date'] = str(saved_start).strip()
        if not filters_template['end_date']:
            saved_end = saved_filters.get('end_date')
            if saved_end:
                filters_template['end_date'] = str(saved_end).strip()

    start_date_raw = filters_template['start_date'] or ''
    end_date_raw = filters_template['end_date'] or ''
    start_date_obj = parse_date(start_date_raw)
    end_date_obj = parse_date(end_date_raw)

    if not start_date_raw or not start_date_obj:
        start_date_obj = first_day
        start_date_raw = first_day.strftime('%Y-%m-%d')
    if not end_date_raw or not end_date_obj:
        end_date_obj = last_day
        end_date_raw = last_day.strftime('%Y-%m-%d')

    filters_template['start_date'] = start_date_raw
    filters_template['end_date'] = end_date_raw

    query_filters = {
        'start_date': start_date_obj,
        'end_date': end_date_obj,
        'vendor': filters_template['vendor'],
        'state': filters_template['state'],
        'customer': filters_template['customer'],
        'line': filters_template['line'],
        'status': filters_template['status'],
        'situation': filters_template['situation'],
        'transaction': filters_template['transaction'],
    }

    data = fetch_orders_by_state(query_filters)
    chart_labels = [row['state'] for row in data]
    chart_values = [row['total'] for row in data]
    total_value = sum(chart_values)

    vendor_options = get_sales_order_vendors()
    vendor_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in vendor_options}
    customer_options = get_sales_order_customers()
    customer_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in customer_options}
    transaction_options = get_sales_order_transactions()
    transaction_label_map = {(opt.get('code') or '').strip(): (opt.get('label') or '').strip() for opt in transaction_options}
    status_options = ORDER_APPROVAL_STATUS_OPTIONS
    status_label_map = ORDER_APPROVAL_STATUS_LABELS
    situation_options = ORDER_SITUATION_OPTIONS
    situation_label_map = ORDER_SITUATION_LABELS

    selected_vendor_labels = []
    for code in filters_template['vendor']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = vendor_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_vendor_labels:
            selected_vendor_labels.append(label)

    selected_state_labels = []
    for state in filters_template['state']:
        label = (state or '').strip()
        if not label:
            continue
        if label not in selected_state_labels:
            selected_state_labels.append(label)

    selected_status_labels = []
    for code in filters_template['status']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = status_label_map.get(normalized, normalized)
        if label not in selected_status_labels:
            selected_status_labels.append(label)

    selected_situation_labels = []
    for code in filters_template['situation']:
        normalized = (code or '').strip().upper()
        if normalized or code == '':
            label = situation_label_map.get(normalized, normalized)
            if label not in selected_situation_labels:
                selected_situation_labels.append(label)

    selected_line_labels = []
    for line in filters_template['line']:
        label = (line or '').strip()
        if not label:
            continue
        if label not in selected_line_labels:
            selected_line_labels.append(label)

    selected_customer_labels = []
    for code in filters_template['customer']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = customer_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_customer_labels:
            selected_customer_labels.append(label)

    selected_transaction_labels = []
    for code in filters_template['transaction']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        label_base = transaction_label_map.get(normalized, '')
        label = f"{label_base} ({normalized})" if label_base and normalized else label_base or normalized
        if label not in selected_transaction_labels:
            selected_transaction_labels.append(label)

    def format_date_label(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
        except (ValueError, TypeError):
            return value

    start_label = format_date_label(start_date_raw)
    end_label = format_date_label(end_date_raw)
    period_label = ''
    if start_label and end_label:
        period_label = f"{start_label} → {end_label}"
    elif start_label:
        period_label = f"A partir de {start_label}"
    elif end_label:
        period_label = f"Até {end_label}"

    return render_template(
        'report_orders_by_state.html',
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_value=total_value,
        filters=filters_template,
        period_label=period_label,
        vendor_options=vendor_options,
        customer_options=customer_options,
        transaction_options=transaction_options,
        line_options=get_distinct_product_lines(),
        state_options=get_distinct_states(),
        status_options=status_options,
        situation_options=situation_options,
        selected_vendor_labels=selected_vendor_labels,
        selected_state_labels=selected_state_labels,
        selected_status_labels=selected_status_labels,
        selected_situation_labels=selected_situation_labels,
        selected_line_labels=selected_line_labels,
        selected_customer_labels=selected_customer_labels,
        selected_transaction_labels=selected_transaction_labels,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )



@app.route('/report_orders_by_state/save_filters', methods=['POST'])
@login_required
def save_report_orders_by_state_filters():
    """Salva a configuração de filtros dos pedidos por estado para o usuário."""
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    def deduplicate_preserve_order(values):
        seen = set()
        ordered = []
        for value in values:
            if value not in seen:
                seen.add(value)
                ordered.append(value)
        return ordered

    def sanitize_multi(field_name, allow_blank=False, uppercase=False):
        values = ensure_list(payload.get(field_name))
        cleaned = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if uppercase and text:
                text = text.upper()
            if text or allow_blank:
                cleaned.append(text)
        return deduplicate_preserve_order(cleaned)

    def sanitize_date(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(str(value).strip(), '%Y-%m-%d').strftime('%Y-%m-%d')
        except (ValueError, TypeError):
            return ''

    sanitized_filters = {
        'start_date': sanitize_date(payload.get('start_date')),
        'end_date': sanitize_date(payload.get('end_date')),
        'vendor': sanitize_multi('vendor'),
        'state': sanitize_multi('state', uppercase=True),
        'customer': sanitize_multi('customer'),
        'line': sanitize_multi('line', uppercase=True),
        'status': sanitize_multi('status', uppercase=True),
        'situation': sanitize_multi('situation', allow_blank=True, uppercase=True),
        'transaction': sanitize_multi('transaction'),
    }

    try:
        saved = save_user_parameters(
            user_id,
            REPORT_ORDERS_BY_STATE_FILTERS_PARAM,
            json.dumps(sanitized_filters)
        )
    except (TypeError, ValueError) as error:
        return jsonify({'success': False, 'message': f'Não foi possível processar os filtros: {error}'}), 400

    if not saved:
        return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500

    return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})


@app.route('/report_orders_by_line')
@login_required
def report_orders_by_line():
    def normalize_values(values, allow_blank=False, uppercase=False):
        normalized = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if not text and not allow_blank:
                continue
            if uppercase and text:
                text = text.upper()
            normalized.append(text)
        return normalized

    def normalize_saved_values(value, allow_blank=False, uppercase=False):
        if value is None:
            return []
        source = value if isinstance(value, list) else [value]
        return normalize_values(source, allow_blank=allow_blank, uppercase=uppercase)

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return None

    user_id = session.get('user_id')
    saved_filters = {}
    if user_id:
        saved_filters_raw = get_user_parameters(user_id, REPORT_ORDERS_LINE_FILTERS_PARAM)
        if saved_filters_raw:
            try:
                saved_filters = json.loads(saved_filters_raw) or {}
            except (TypeError, ValueError):
                saved_filters = {}

    filter_applied_flag = (request.args.get('filter_applied') or '').strip() == '1'
    ignore_saved_flag = (request.args.get('ignore_saved') or '').strip() == '1'
    use_saved_defaults = bool(saved_filters) and not filter_applied_flag and not ignore_saved_flag

    today = datetime.date.today()
    first_day = today.replace(day=1)
    last_day = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    start_date_raw = (request.args.get('start_date') or '').strip()
    end_date_raw = (request.args.get('end_date') or '').strip()

    if use_saved_defaults:
        if not start_date_raw:
            start_date_raw = str(saved_filters.get('start_date') or '').strip()
        if not end_date_raw:
            end_date_raw = str(saved_filters.get('end_date') or '').strip()

    vendor_values = normalize_values(request.args.getlist('vendor'))
    if use_saved_defaults and not vendor_values:
        vendor_values = normalize_saved_values(saved_filters.get('vendor'))

    state_values = normalize_values(request.args.getlist('state'), uppercase=True)
    if use_saved_defaults and not state_values:
        state_values = normalize_saved_values(saved_filters.get('state'), uppercase=True)

    customer_values = normalize_values(request.args.getlist('customer'))
    if use_saved_defaults and not customer_values:
        customer_values = normalize_saved_values(saved_filters.get('customer'))

    line_values = normalize_values(request.args.getlist('line'), uppercase=True)
    if use_saved_defaults and not line_values:
        line_values = normalize_saved_values(saved_filters.get('line'), uppercase=True)

    status_values = normalize_values(request.args.getlist('status'), uppercase=True)
    if use_saved_defaults and not status_values:
        status_values = normalize_saved_values(saved_filters.get('status'), uppercase=True)

    situation_values = normalize_values(request.args.getlist('situation'), allow_blank=True, uppercase=True)
    if use_saved_defaults and not situation_values:
        situation_values = normalize_saved_values(saved_filters.get('situation'), allow_blank=True, uppercase=True)

    transaction_values = normalize_values(request.args.getlist('transaction'))
    if use_saved_defaults and not transaction_values:
        transaction_values = normalize_saved_values(saved_filters.get('transaction'))

    if not start_date_raw:
        start_date_raw = first_day.strftime('%Y-%m-%d')
    if not end_date_raw:
        end_date_raw = last_day.strftime('%Y-%m-%d')

    start_date_obj = parse_date(start_date_raw)
    end_date_obj = parse_date(end_date_raw)

    filters_template = {
        'start_date': start_date_raw,
        'end_date': end_date_raw,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    query_filters = {
        'start_date': start_date_obj,
        'end_date': end_date_obj,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    data = fetch_orders_by_line(query_filters)
    chart_labels = [row['line'] for row in data]
    chart_values = [row['total'] for row in data]
    total_value = sum(chart_values)

    vendor_options = get_sales_order_vendors()
    vendor_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in vendor_options}
    customer_options = get_sales_order_customers()
    customer_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in customer_options}
    transaction_options = get_sales_order_transactions()
    transaction_label_map = {(opt.get('code') or '').strip(): (opt.get('label') or '').strip() for opt in transaction_options}
    status_options = ORDER_APPROVAL_STATUS_OPTIONS
    status_label_map = ORDER_APPROVAL_STATUS_LABELS
    situation_options = ORDER_SITUATION_OPTIONS
    situation_label_map = ORDER_SITUATION_LABELS

    selected_vendor_labels = []
    for code in filters_template['vendor']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = vendor_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_vendor_labels:
            selected_vendor_labels.append(label)

    selected_state_labels = []
    for state in filters_template['state']:
        label = (state or '').strip()
        if not label:
            continue
        if label not in selected_state_labels:
            selected_state_labels.append(label)

    selected_status_labels = []
    for code in filters_template['status']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = status_label_map.get(normalized, normalized)
        if label not in selected_status_labels:
            selected_status_labels.append(label)

    selected_situation_labels = []
    for code in filters_template['situation']:
        normalized = (code or '').strip().upper()
        if normalized or code == '':
            label = situation_label_map.get(normalized, normalized)
            if label not in selected_situation_labels:
                selected_situation_labels.append(label)

    selected_line_labels = []
    for line in filters_template['line']:
        label = (line or '').strip()
        if not label:
            continue
        if label not in selected_line_labels:
            selected_line_labels.append(label)

    selected_customer_labels = []
    for code in filters_template['customer']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = customer_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_customer_labels:
            selected_customer_labels.append(label)

    selected_transaction_labels = []
    for code in filters_template['transaction']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = transaction_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_transaction_labels:
            selected_transaction_labels.append(label)

    def format_date_label(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
        except (ValueError, TypeError):
            return value

    start_label = format_date_label(start_date_raw)
    end_label = format_date_label(end_date_raw)
    period_label = ''
    if start_label and end_label:
        period_label = f"{start_label} → {end_label}"
    elif start_label:
        period_label = f"A partir de {start_label}"
    elif end_label:
        period_label = f"Até {end_label}"

    return render_template(
        'report_orders_by_line.html',
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_value=total_value,
        filters=filters_template,
        period_label=period_label,
        vendor_options=vendor_options,
        customer_options=customer_options,
        transaction_options=transaction_options,
        status_options=status_options,
        situation_options=situation_options,
        line_options=get_distinct_product_lines(),
        state_options=get_distinct_states(),
        selected_vendor_labels=selected_vendor_labels,
        selected_state_labels=selected_state_labels,
        selected_status_labels=selected_status_labels,
        selected_situation_labels=selected_situation_labels,
        selected_line_labels=selected_line_labels,
        selected_customer_labels=selected_customer_labels,
        selected_transaction_labels=selected_transaction_labels,
        save_filters_url=url_for('save_report_orders_by_line_filters'),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_orders_by_line/save_filters', methods=['POST'])
@login_required
def save_report_orders_by_line_filters():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    def deduplicate_preserve_order(values):
        seen = set()
        ordered = []
        for value in values:
            if value in seen:
                continue
            seen.add(value)
            ordered.append(value)
        return ordered

    def sanitize_multi(field_name, allow_blank=False, uppercase=False):
        values = ensure_list(payload.get(field_name))
        cleaned = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if uppercase and text:
                text = text.upper()
            if text or allow_blank:
                cleaned.append(text)
        return deduplicate_preserve_order(cleaned)

    def sanitize_date(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%Y-%m-%d')
        except (ValueError, TypeError):
            return ''

    sanitized_filters = {
        'start_date': sanitize_date(payload.get('start_date')),
        'end_date': sanitize_date(payload.get('end_date')),
        'vendor': sanitize_multi('vendor'),
        'state': sanitize_multi('state', uppercase=True),
        'customer': sanitize_multi('customer'),
        'line': sanitize_multi('line', uppercase=True),
        'status': sanitize_multi('status', uppercase=True),
        'situation': sanitize_multi('situation', uppercase=True, allow_blank=True),
        'transaction': sanitize_multi('transaction'),
    }

    try:
        saved = save_user_parameters(
            user_id,
            REPORT_ORDERS_LINE_FILTERS_PARAM,
            json.dumps(sanitized_filters)
        )
        if not saved:
            raise RuntimeError('Não foi possível salvar os filtros.')
        return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})
    except Exception as err:
        print(f'Erro ao salvar filtros de Pedidos por Linha: {err}')
        return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500


@app.route('/report_decomposition_tree')
@login_required
def report_decomposition_tree():
    def normalize_values(values, allow_blank=False, uppercase=False):
        normalized = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if uppercase and text:
                text = text.upper()
            if not text and not allow_blank:
                continue
            normalized.append(text)
        return normalized

    def normalize_saved_values(value, allow_blank=False, uppercase=False):
        if value is None:
            return []
        source = value if isinstance(value, list) else [value]
        return normalize_values(source, allow_blank=allow_blank, uppercase=uppercase)

    def parse_date(value):
        if not value:
            return None
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return None

    user_id = session.get('user_id')
    saved_filters = {}
    if user_id:
        saved_filters_raw = get_user_parameters(user_id, REPORT_DECOMPOSITION_TREE_FILTERS_PARAM)
        if saved_filters_raw:
            try:
                saved_filters = json.loads(saved_filters_raw) or {}
            except (TypeError, ValueError):
                saved_filters = {}

    filter_applied_flag = (request.args.get('filter_applied') or '').strip() == '1'
    ignore_saved_flag = (request.args.get('ignore_saved') or '').strip() == '1'
    use_saved_defaults = bool(saved_filters) and not filter_applied_flag and not ignore_saved_flag

    today = datetime.date.today()
    first_day = today.replace(day=1)
    last_day = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    start_date_raw = (request.args.get('start_date') or '').strip()
    end_date_raw = (request.args.get('end_date') or '').strip()

    if use_saved_defaults:
        if not start_date_raw:
            start_date_raw = str(saved_filters.get('start_date') or '').strip()
        if not end_date_raw:
            end_date_raw = str(saved_filters.get('end_date') or '').strip()

    vendor_values = normalize_values(request.args.getlist('vendor'))
    if use_saved_defaults and not vendor_values:
        vendor_values = normalize_saved_values(saved_filters.get('vendor'))

    state_values = normalize_values(request.args.getlist('state'), uppercase=True)
    if use_saved_defaults and not state_values:
        state_values = normalize_saved_values(saved_filters.get('state'), uppercase=True)

    customer_values = normalize_values(request.args.getlist('customer'))
    if use_saved_defaults and not customer_values:
        customer_values = normalize_saved_values(saved_filters.get('customer'))

    line_values = normalize_values(request.args.getlist('line'), uppercase=True)
    if use_saved_defaults and not line_values:
        line_values = normalize_saved_values(saved_filters.get('line'), uppercase=True)

    status_values = normalize_values(request.args.getlist('status'), uppercase=True)
    if use_saved_defaults and not status_values:
        status_values = normalize_saved_values(saved_filters.get('status'), uppercase=True)

    situation_values = normalize_values(
        request.args.getlist('situation'),
        allow_blank=True,
        uppercase=True,
    )
    if use_saved_defaults and not situation_values:
        situation_values = normalize_saved_values(
            saved_filters.get('situation'),
            allow_blank=True,
            uppercase=True,
        )

    transaction_values = normalize_values(request.args.getlist('transaction'))
    if use_saved_defaults and not transaction_values:
        transaction_values = normalize_saved_values(saved_filters.get('transaction'))

    if not start_date_raw:
        start_date_raw = first_day.strftime('%Y-%m-%d')
    if not end_date_raw:
        end_date_raw = last_day.strftime('%Y-%m-%d')

    start_date_obj = parse_date(start_date_raw)
    end_date_obj = parse_date(end_date_raw)

    filters_template = {
        'start_date': start_date_raw,
        'end_date': end_date_raw,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    query_filters = {
        'start_date': start_date_obj,
        'end_date': end_date_obj,
        'vendor': vendor_values,
        'state': state_values,
        'customer': customer_values,
        'line': line_values,
        'status': status_values,
        'situation': situation_values,
        'transaction': transaction_values,
    }

    rows = fetch_decomposition_tree(query_filters)
    tree_map = {}
    total_value = 0.0

    def format_label(name, code, fallback):
        name_text = (name or '').strip()
        code_text = (code or '').strip()
        if name_text and code_text:
            return f"{name_text} ({code_text})"
        if name_text:
            return name_text
        if code_text:
            return code_text
        return fallback

    def ensure_node(mapping, label):
        node = mapping.get(label)
        if not node:
            node = {'label': label, 'value': 0.0, 'children': {}}
            mapping[label] = node
        return node

    for row in rows:
        value = float(row.get('total_value') or 0)
        total_value += value

        vendor_label = format_label(row.get('vendor_name'), row.get('vendor_code'), 'Sem Representante')
        vendor_node = ensure_node(tree_map, vendor_label)
        vendor_node['value'] += value

        city_label = row.get('city') or 'Sem Cidade'
        city_node = ensure_node(vendor_node['children'], city_label)
        city_node['value'] += value

        customer_label = format_label(row.get('customer_name'), row.get('customer_code'), 'Sem Cliente')
        customer_node = ensure_node(city_node['children'], customer_label)
        customer_node['value'] += value

        line_label = (row.get('line') or 'OUTROS').strip() or 'OUTROS'
        line_node = ensure_node(customer_node['children'], line_label)
        line_node['value'] += value

        sub_group_label = row.get('sub_group') or 'Sem SubGrupo'
        sub_group_node = ensure_node(line_node['children'], sub_group_label)
        sub_group_node['value'] += value

        product_label = format_label(row.get('product_name'), row.get('product_code'), 'Sem Produto')
        product_node = ensure_node(sub_group_node['children'], product_label)
        product_node['value'] += value

    def map_to_list(mapping):
        nodes = []
        for node in mapping.values():
            children = map_to_list(node['children']) if node['children'] else []
            nodes.append({
                'label': node['label'],
                'value': round(node['value'], 2),
                'children': children,
            })
        return nodes

    tree_data = map_to_list(tree_map)

    vendor_options = get_sales_order_vendors()
    vendor_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in vendor_options}
    customer_options = get_sales_order_customers()
    customer_label_map = {(opt.get('code') or '').strip(): (opt.get('name') or '').strip() for opt in customer_options}
    transaction_options = get_sales_order_transactions()
    transaction_label_map = {(opt.get('code') or '').strip(): (opt.get('label') or '').strip() for opt in transaction_options}
    status_options = ORDER_APPROVAL_STATUS_OPTIONS
    status_label_map = ORDER_APPROVAL_STATUS_LABELS
    situation_options = ORDER_SITUATION_OPTIONS
    situation_label_map = ORDER_SITUATION_LABELS

    selected_vendor_labels = []
    for code in filters_template['vendor']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = vendor_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_vendor_labels:
            selected_vendor_labels.append(label)

    selected_state_labels = []
    for state in filters_template['state']:
        label = (state or '').strip()
        if not label:
            continue
        if label not in selected_state_labels:
            selected_state_labels.append(label)

    selected_customer_labels = []
    for code in filters_template['customer']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = customer_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_customer_labels:
            selected_customer_labels.append(label)

    selected_line_labels = []
    for line in filters_template['line']:
        label = (line or '').strip()
        if not label:
            continue
        if label not in selected_line_labels:
            selected_line_labels.append(label)

    selected_status_labels = []
    for code in filters_template['status']:
        normalized = (code or '').strip().upper()
        if not normalized:
            continue
        label = status_label_map.get(normalized, normalized)
        if label not in selected_status_labels:
            selected_status_labels.append(label)

    selected_situation_labels = []
    for code in filters_template['situation']:
        normalized = (code or '').strip().upper()
        if normalized or code == '':
            label = situation_label_map.get(normalized, normalized)
            if label not in selected_situation_labels:
                selected_situation_labels.append(label)

    selected_transaction_labels = []
    for code in filters_template['transaction']:
        normalized = (code or '').strip()
        if not normalized:
            continue
        name = transaction_label_map.get(normalized, '')
        label = f"{name} ({normalized})" if name and normalized else name or normalized
        if label not in selected_transaction_labels:
            selected_transaction_labels.append(label)

    def format_date_label(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
        except (ValueError, TypeError):
            return value

    start_label = format_date_label(start_date_raw)
    end_label = format_date_label(end_date_raw)
    period_label = ''
    if start_label and end_label:
        period_label = f"{start_label} → {end_label}"
    elif start_label:
        period_label = f"A partir de {start_label}"
    elif end_label:
        period_label = f"Até {end_label}"

    return render_template(
        'report_decomposition_tree.html',
        tree_data=tree_data,
        total_value=round(total_value, 2),
        filters=filters_template,
        period_label=period_label,
        vendor_options=vendor_options,
        customer_options=customer_options,
        transaction_options=transaction_options,
        status_options=status_options,
        situation_options=situation_options,
        line_options=get_distinct_product_lines(),
        state_options=get_distinct_states(),
        selected_vendor_labels=selected_vendor_labels,
        selected_state_labels=selected_state_labels,
        selected_customer_labels=selected_customer_labels,
        selected_line_labels=selected_line_labels,
        selected_status_labels=selected_status_labels,
        selected_situation_labels=selected_situation_labels,
        selected_transaction_labels=selected_transaction_labels,
        save_filters_url=url_for('save_report_decomposition_tree_filters'),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
    )


@app.route('/report_decomposition_tree/save_filters', methods=['POST'])
@login_required
def save_report_decomposition_tree_filters():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    def deduplicate_preserve_order(values):
        seen = set()
        ordered = []
        for value in values:
            if value in seen:
                continue
            seen.add(value)
            ordered.append(value)
        return ordered

    def sanitize_multi(field_name, allow_blank=False, uppercase=False):
        values = ensure_list(payload.get(field_name))
        cleaned = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if uppercase and text:
                text = text.upper()
            if text or allow_blank:
                cleaned.append(text)
        return deduplicate_preserve_order(cleaned)

    def sanitize_date(value):
        if not value:
            return ''
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').strftime('%Y-%m-%d')
        except (ValueError, TypeError):
            return ''

    sanitized_filters = {
        'start_date': sanitize_date(payload.get('start_date')),
        'end_date': sanitize_date(payload.get('end_date')),
        'vendor': sanitize_multi('vendor'),
        'state': sanitize_multi('state', uppercase=True),
        'customer': sanitize_multi('customer'),
        'line': sanitize_multi('line', uppercase=True),
        'status': sanitize_multi('status', uppercase=True),
        'situation': sanitize_multi('situation', allow_blank=True, uppercase=True),
        'transaction': sanitize_multi('transaction'),
    }

    try:
        saved = save_user_parameters(
            user_id,
            REPORT_DECOMPOSITION_TREE_FILTERS_PARAM,
            json.dumps(sanitized_filters)
        )
        if not saved:
            raise RuntimeError('Não foi possível salvar os filtros.')
        return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})
    except Exception as err:
        print(f'Erro ao salvar filtros da Árvore de Decomposição: {err}')
        return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500


@app.route('/report_sales_orders_comparison/save_filters', methods=['POST'])
@login_required
def save_report_sales_orders_comparison_filters():
    """Salva os filtros escolhidos no comparativo mensal para reutilização futura."""
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Usuário não autenticado.'}), 401

    payload = request.get_json(silent=True) or {}

    def ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        return [value]

    def deduplicate_preserve_order(values):
        seen = set()
        ordered = []
        for value in values:
            if value not in seen:
                seen.add(value)
                ordered.append(value)
        return ordered

    def sanitize_multi(field_name, allow_blank=False, numeric_range=None):
        values = ensure_list(payload.get(field_name))
        cleaned = []
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if numeric_range:
                if not text:
                    continue
                try:
                    number = int(text)
                except (TypeError, ValueError):
                    continue
                min_allowed, max_allowed = numeric_range
                if number < min_allowed or number > max_allowed:
                    continue
                cleaned.append(str(number))
                continue
            if text or allow_blank:
                cleaned.append(text)
        return deduplicate_preserve_order(cleaned)

    def sanitize_year(value):
        if value is None:
            return datetime.date.today().year
        try:
            return int(str(value).strip())
        except (TypeError, ValueError):
            return datetime.date.today().year

    sanitized_filters = {
        'year': sanitize_year(payload.get('year')),
        'month': sanitize_multi('month', numeric_range=(1, 12)),
        'vendor': sanitize_multi('vendor'),
        'state': sanitize_multi('state'),
        'status': sanitize_multi('status'),
        'situation': sanitize_multi('situation', allow_blank=True),
        'line': sanitize_multi('line'),
        'customer': sanitize_multi('customer'),
        'transaction': sanitize_multi('transaction'),
    }

    try:
        saved = save_user_parameters(
            user_id,
            REPORT_SALES_COMPARISON_FILTERS_PARAM,
            json.dumps(sanitized_filters)
        )
    except (TypeError, ValueError) as error:
        return jsonify({'success': False, 'message': f'Não foi possível processar os filtros: {error}'}), 400

    if not saved:
        return jsonify({'success': False, 'message': 'Não foi possível salvar os filtros.'}), 500

    return jsonify({'success': True, 'message': 'Filtros salvos com sucesso.'})


# Página intermediária para relatórios de faturamento
@app.route('/revenue_reports')
@login_required
def revenue_reports():
    """Página de seleção dos relatórios de faturamento."""
    return render_template('revenue_reports.html', page_title="Relatórios de Faturamento", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/report_revenue_comparison')
@login_required
def report_revenue_comparison():
    """Exibe um comparativo de faturamento anual (ano atual x ano anterior)."""

    current_year = int(request.args.get('year', datetime.date.today().year))

    vendor_status = request.args.getlist('vendor_status')
    if not request.args.get('filter_applied') and not vendor_status:
        vendor_status = ['A']

    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.getlist('state'),
        'city': request.args.getlist('city'),
        'vendor': request.args.getlist('vendor'),
        'vendor_status': vendor_status,
        'line': request.args.getlist('line')
    }

    data_filters = filters.copy()
    data_filters.pop('vendor_status', None)

    prev_year = current_year - 1
    current_data_all = fetch_monthly_revenue(current_year, data_filters)
    prev_filters = data_filters.copy()
    previous_data_all = fetch_monthly_revenue(prev_year, prev_filters)

    months_selected = [int(m) for m in filters['month']] if filters['month'] else list(range(1,13))
    labels = [f"{str(m).zfill(2)}/{current_year}" for m in months_selected]
    current_data = [current_data_all[m-1] for m in months_selected]
    previous_data = [previous_data_all[m-1] for m in months_selected]

    current_total = sum(current_data)
    previous_total = sum(previous_data)
    totals = {
        'current_total': current_total,
        'current_average': current_total / len(months_selected) if months_selected else 0,
        'previous_total': previous_total,
        'previous_average': previous_total / len(months_selected) if months_selected else 0,
        'variation_percent': ((current_total - previous_total) / previous_total * 100) if previous_total else 0
    }

    return render_template(
        'report_revenue_comparison.html',
        chart_labels=labels,
        current_year_data=current_data,
        previous_year_data=previous_data,
        current_year_label=str(current_year),
        previous_year_label=str(prev_year),
        totals=totals,
        filters=filters,
        states=get_distinct_states(),
        cities=get_distinct_cities(),
        vendors=get_distinct_vendors(),
        vendor_statuses=get_distinct_vendor_statuses(),
        product_lines=get_distinct_product_lines(),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


# --- Rotas de Placeholder para o Menu (Gerencial) ---
@app.route('/backup_db')
@login_required
def backup_db():
    """Rota placeholder para backup do banco de dados."""
    return render_template('placeholder.html', page_title="Backup do Banco de Dados", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/gerencial/parameters', methods=['GET', 'POST'])
@login_required
def gerencial_parameters():
    """
    Rota para a tela de parâmetros do sistema.
    Permite ao usuário selecionar transações que devem ser apresentadas no Espelho de Notas Fiscais.
    """
    user_id = session.get('user_id')

    available_reports = AVAILABLE_PARAMETER_REPORTS
    report_ids = [r[0] for r in available_reports]
    selected_report = request.form.get('report') if request.method == 'POST' else request.args.get('report')
    if selected_report not in report_ids:
        selected_report = available_reports[0][0]
    
    conn_erp = get_erp_db_connection()
    all_transactions = []
    all_cfops = []
    if conn_erp:
        try:
            cur_erp = conn_erp.cursor()
            cur_erp.execute("SELECT transacao, trsnome FROM transa ORDER BY trsnome;")
            # Ensure transacao values are stored as strings to match form inputs
            all_transactions = [{'transacao': str(t[0]), 'trsnome': t[1]} for t in cur_erp.fetchall()]
            
            cur_erp.execute("SELECT operacao FROM opera ORDER BY operacao;")
            all_cfops = [str(row[0]).strip() for row in cur_erp.fetchall() if row and row[0]]

            cur_erp.close()
        except Error as e:
            print(f"Erro ao buscar transações ou CFOPs: {e}")
            flash(f"Erro ao carregar transações ou CFOPs: {e}", "danger")
        finally:
            if conn_erp:
                conn_erp.close()

    if request.method == 'POST':
        selected_transactions = request.form.getlist('selected_transactions')
        selected_transactions_str = ','.join(selected_transactions)
        
        transaction_signs = {}
        for trans in selected_transactions:
            sign = request.form.get(f'sign_{trans}', '+')
            if sign not in ['+', '-']:
                sign = '+'
            transaction_signs[trans] = sign
        transaction_signs_str = ','.join(f'{t}:{s}' for t, s in transaction_signs.items())

        selected_cfops = [c.strip() for c in request.form.getlist('selected_cfops')]
        selected_cfops_str = ','.join(selected_cfops)

        success = True
        if not save_user_parameters(user_id, f'{selected_report}_selected_invoice_transactions', selected_transactions_str):
            success = False
        if not save_user_parameters(user_id, f'{selected_report}_invoice_transaction_signs', transaction_signs_str):
            success = False
        if not save_user_parameters(user_id, f'{selected_report}_selected_report_cfops', selected_cfops_str):
            success = False
        media_base_path = request.form.get('assistance_media_base_path', '').strip()
        if not save_user_parameters(user_id, ASSISTANCE_MEDIA_PATH_PARAM, media_base_path):
            success = False
        if success:
            flash('Parâmetros salvos com sucesso!', 'success')
        else:
            flash('Falha ao salvar os parâmetros solicitados.', 'danger')
        return redirect(url_for('gerencial_parameters', report=selected_report))
    
    # GET request: Load current selected transactions and signs
    current_signs_str = get_user_parameters(user_id, f'{selected_report}_invoice_transaction_signs')
    current_transaction_signs = parse_transaction_signs(current_signs_str)
    current_selected_transactions = list(current_transaction_signs.keys())
    if not current_selected_transactions:
        current_selected_transactions_str = get_user_parameters(user_id, f'{selected_report}_selected_invoice_transactions')
        if current_selected_transactions_str:
            current_selected_transactions = [t.strip() for t in current_selected_transactions_str.split(',') if t.strip()]
            current_transaction_signs = {t: '+' for t in current_selected_transactions}

    selected_cfops_str = get_user_parameters(user_id, f'{selected_report}_selected_report_cfops')
    current_selected_cfops = []
    if selected_cfops_str:
        current_selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

    assistance_media_base_path = get_user_parameters(user_id, ASSISTANCE_MEDIA_PATH_PARAM) or ''

    # Marcar as transações e CFOPs que já estão selecionados
    for trans in all_transactions:
        code = trans['transacao']
        trans['is_selected'] = code in current_selected_transactions
        trans['sign'] = current_transaction_signs.get(code, '+')

    cfops_data = []
    for cfop in all_cfops:
        cfops_data.append({'cfop': cfop, 'is_selected': cfop in current_selected_cfops})

    return render_template(
        'parameters.html',
        page_title="Parâmetros do Sistema",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
        all_transactions=all_transactions,
        all_cfops=cfops_data,
        available_reports=available_reports,
        selected_report=selected_report,
        assistance_media_base_path=assistance_media_base_path,
    )


@app.route('/users_list')
@login_required
def users_list():
    """
    Rota para listar os usuários cadastrados no siga_db com filtros.
    """
    conn = get_siga_db_connection()
    users = []
    
    filters = {
        'username_filter': request.args.get('username_filter')
    }

    if conn:
        try:
            cur = conn.cursor()
            sql_query = "SELECT id, username FROM users WHERE 1=1"
            query_params = []

            if filters['username_filter']:
                sql_query += " AND username ILIKE %s"
                query_params.append(f"%{filters['username_filter']}%")

            sql_query += " ORDER BY username;"
            
            cur.execute(sql_query, tuple(query_params))
            users = cur.fetchall()
            cur.close()
        except Error as e:
            print(f"Erro ao carregar lista de usuários: {e}")
            flash(f"Erro ao carregar usuários: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('users_list.html', users=users, filters=filters, page_title="Lista de Usuários", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/logout')
def logout():
    """
    Rota para fazer logout do sistema.
    """
    session.pop('logged_in', None)
    session.pop('username', None)
    session.pop('user_id', None) # Limpa o user_id também
    flash('Você foi desconectado.', 'info')
    return redirect(url_for('login'))

# Adiciona um print para depuração do mapa de URLs
if __name__ == '__main__':
    print("Flask URL Map:")
    for rule in app.url_map.iter_rules():
        print(f"Endpoint: {rule.endpoint}, Methods: {rule.methods}, Rule: {rule.rule}")
    app.run(host="0.0.0.0", port=5001, debug=True)
