#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CODE_DIR="${WORKSPACE}/code"
TESTS_DIR="${WORKSPACE}/tests"
SOURCE="${CODE_DIR}/escudos.c"
PROGRAM="${CODE_DIR}/escudos"
TEMP_DIR="$(mktemp -d)"
VALIDATION_PROGRAM="${TEMP_DIR}/escudos"
PASSES=0
FAILURES=0

trap 'rm -rf -- "${TEMP_DIR}"' EXIT

pass() {
    printf 'PASS: %s\n' "$1"
    PASSES=$((PASSES + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

check() {
    local description="$1"
    shift

    if "$@"; then
        pass "${description}"
    else
        fail "${description}"
    fi
}

compiles_cleanly() {
    local description=""

    gcc -Wall -Wextra -Werror -std=c11 "${SOURCE}" \
        -o "${VALIDATION_PROGRAM}" >/dev/null 2>&1 || return 1

    [[ -f "${PROGRAM}" && -x "${PROGRAM}" ]] || return 1
    description="$(file -b -- "${PROGRAM}")"
    [[ "${description}" == ELF*executable* ]]
}

debug_helper_works() {
    local source_object="${TEMP_DIR}/escudos.o"
    local harness_source="${TEMP_DIR}/debug-helper.c"
    local harness_program="${TEMP_DIR}/debug-helper"
    local output_file="${TEMP_DIR}/debug-helper.out"
    local error_file="${TEMP_DIR}/debug-helper.err"
    local expected_file="${TEMP_DIR}/debug-helper.expected"

    printf '%s\n' \
        'extern int debug_enabled;' \
        'void myprint(const char *label, int value, int condition);' \
        'int main(void)' \
        '{' \
        '    debug_enabled = 0;' \
        '    myprint("oculta_global", 7, 1);' \
        '    debug_enabled = 1;' \
        '    myprint("oculta_local", 8, 0);' \
        '    myprint("visible", 9, 1);' \
        '    return 0;' \
        '}' > "${harness_source}"
    printf 'DEBUG: visible=9\n' > "${expected_file}"

    gcc -Wall -Wextra -Werror -std=c11 -Dmain=escudos_student_main \
        -c "${SOURCE}" -o "${source_object}" >/dev/null 2>&1 || return 1
    gcc -Wall -Wextra -Werror -std=c11 "${harness_source}" \
        "${source_object}" -o "${harness_program}" >/dev/null 2>&1 || return 1
    "${harness_program}" > "${output_file}" 2> "${error_file}" || return 1

    [[ ! -s "${output_file}" ]] || return 1
    cmp -s "${expected_file}" "${error_file}"
}

all_test_cases_exist() {
    local number=0
    local test_name=""

    for ((number = 1; number <= 10; number++)); do
        printf -v test_name 'test%03d' "${number}"
        [[ -f "${TESTS_DIR}/${test_name}.in" ]] || return 1
        [[ -f "${TESTS_DIR}/${test_name}.expected" ]] || return 1
    done
}

program_matches() {
    local input="$1"
    local expected="$2"
    local input_file="${TEMP_DIR}/case.in"
    local expected_file="${TEMP_DIR}/case.expected"
    local output_file="${TEMP_DIR}/case.out"

    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1
    printf '%s' "${input}" > "${input_file}"
    printf '%s' "${expected}" > "${expected_file}"

    timeout 3 "${VALIDATION_PROGRAM}" < "${input_file}" \
        > "${output_file}" 2>/dev/null || return 1
    cmp -s "${expected_file}" "${output_file}"
}

initial_control_is_correct() {
    program_matches \
        $'20\n10\n0\n0\n0\n0\n0\n1\ntransferencia reserva frente 5\n' \
        $'Energia total: 30\nReserva: 15\nFrente: 15\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 0\nEstado escudos: operativo\nEstado nave: activa\n'
}

transfers_preserve_energy() {
    program_matches \
        $'3\n10\n4\n4\n4\n4\n4\n2\ntransferencia reserva frente 1\ntransferencia atras frente 2\n' \
        $'Energia total: 33\nReserva: 2\nFrente: 13\nAtras: 2\nIzquierda: 4\nDerecha: 4\nArriba: 4\nAbajo: 4\nDano nave: 0\nEstado escudos: operativo\nEstado nave: activa\n'
}

impact_is_correct() {
    program_matches \
        $'12\n10\n0\n0\n0\n0\n0\n1\nimpacto frente 5\n' \
        $'Energia total: 19\nReserva: 12\nFrente: 7\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 0\nEstado escudos: critico\nEstado nave: activa\n'
}

all_source_energy_can_be_transferred() {
    program_matches \
        $'9\n0\n4\n0\n0\n0\n0\n1\ntransferencia reserva atras 9\n' \
        $'Energia total: 13\nReserva: 0\nFrente: 0\nAtras: 13\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 0\nEstado escudos: critico\nEstado nave: activa\n'
}

right_sector_is_used() {
    program_matches \
        $'5\n0\n0\n0\n8\n0\n0\n1\nimpacto derecha 4\n' \
        $'Energia total: 11\nReserva: 5\nFrente: 0\nAtras: 0\nIzquierda: 0\nDerecha: 6\nArriba: 0\nAbajo: 0\nDano nave: 0\nEstado escudos: critico\nEstado nave: activa\n'
}

capacity_is_used_completely() {
    program_matches \
        $'12\n0\n0\n0\n0\n39\n0\n1\ntransferencia reserva arriba 5\n' \
        $'Energia total: 51\nReserva: 11\nFrente: 0\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 40\nAbajo: 0\nDano nave: 0\nEstado escudos: operativo\nEstado nave: activa\n'
}

excess_damage_reaches_ship() {
    program_matches \
        $'15\n0\n0\n0\n0\n0\n1\n1\nimpacto abajo 5\n' \
        $'Energia total: 15\nReserva: 15\nFrente: 0\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 2\nEstado escudos: critico\nEstado nave: activa\n'
}

ship_is_destroyed_at_threshold() {
    program_matches \
        $'35\n0\n0\n0\n0\n0\n0\n1\nimpacto frente 12\n' \
        $'Energia total: 35\nReserva: 35\nFrente: 0\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 10\nEstado escudos: operativo\nEstado nave: destruida\n'
}

final_state_is_classified() {
    program_matches \
        $'20\n15\n0\n0\n0\n0\n0\n1\nimpacto frente 12\n' \
        $'Energia total: 25\nReserva: 20\nFrente: 5\nAtras: 0\nIzquierda: 0\nDerecha: 0\nArriba: 0\nAbajo: 0\nDano nave: 0\nEstado escudos: critico\nEstado nave: activa\n'
}

has_clean_stderr() {
    local input_file=""
    local output_file="${TEMP_DIR}/clean.out"
    local error_file="${TEMP_DIR}/clean.err"

    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1

    for input_file in "${TESTS_DIR}"/test*.in; do
        timeout 3 "${VALIDATION_PROGRAM}" < "${input_file}" \
            > "${output_file}" 2> "${error_file}" || return 1
        [[ ! -s "${error_file}" ]] || return 1
    done
}

suite_passes() {
    all_test_cases_exist || return 1
    [[ -x "${SCRIPT_DIR}/tests-run.sh" ]] || return 1
    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1
    "${SCRIPT_DIR}/tests-run.sh" "${VALIDATION_PROGRAM}" \
        "${TESTS_DIR}" >/dev/null 2>&1
}

printf '%s\n' '========================================='
printf '%s\n' '==   Verificación de laboratorio PF2   =='
printf '%s\n' '========================================='
printf '\n== Actividades ==========================\n\n'

check "[1.2] El programa compila sin warnings y escudos corresponde a un binario" compiles_cleanly
check "[1.3] tests-run.sh tiene permiso de ejecución" test -x "${SCRIPT_DIR}/tests-run.sh"
check "[1.3] Existen los diez pares de archivos de prueba" all_test_cases_exist
check "[1.3] Los casos de control mantienen su comportamiento" initial_control_is_correct
check "[1.3] Las transferencias entre sectores conservan la energía" transfers_preserve_energy
check "[2.2] La función myprint combina los controles global y local" debug_helper_works
check "[2.3] Los impactos reducen correctamente la energía" impact_is_correct
check "[3.3] Toda la energía disponible puede trasladarse" all_source_energy_can_be_transferred
check "[4.1] Los eventos afectan al sector indicado" right_sector_is_used
check "[4.2] La transferencia aprovecha la capacidad del sector" capacity_is_used_completely
check "[5.1] El daño excedente llega a la nave" excess_damage_reaches_ship
check "[5.1] La nave se destruye al alcanzar el límite de daño" ship_is_destroyed_at_threshold
check "[5.2] El estado general considera el resultado final" final_state_is_classified
check "[6.1] El programa no emite trazas con la depuración desactivada" has_clean_stderr
check "[6.2] La suite completa finaliza correctamente" suite_passes
check "[7.1] check.sh tiene permiso de ejecución" test -x "${SCRIPT_DIR}/check.sh"

printf '\n== Resumen ===============================\n\n'
TOTAL=$((PASSES + FAILURES))
COUNT_WIDTH=${#TOTAL}
printf '%-26s %*d\n' 'Comprobaciones exitosas:' "${COUNT_WIDTH}" "${PASSES}"
printf '%-26s %*d\n\n' 'Comprobaciones pendientes:' "${COUNT_WIDTH}" "${FAILURES}"

if (( FAILURES == 0 )); then
    exit 0
fi

exit 1
