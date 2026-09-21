#!/usr/bin/env bash

set -u

PROGRAM="${1:-}"
TESTS_DIR="${2:-}"
TOTAL=0
PASSES=0
FAILURES=0
ERRORS=0

if [[ -z "${PROGRAM}" || -z "${TESTS_DIR}" ]]; then
    printf 'Uso: %s <RUTA_AL_EJECUTABLE> <DIRECTORIO_DE_TESTS>\n' "$0"
    exit 2
fi

if [[ ! -x "${PROGRAM}" ]]; then
    printf 'ERRO:  No se encontró el ejecutable %s\n' "${PROGRAM}"
    exit 2
fi

if [[ ! -d "${TESTS_DIR}" ]]; then
    printf 'ERRO:  No se encontró el directorio %s\n' "${TESTS_DIR}"
    exit 2
fi

ulimit -c 0

printf '%s\n' '========================================='
printf '%s\n' '==            Test cases               =='
printf '%s\n' '========================================='
printf '\n== Resultados ===========================\n\n'

shopt -s nullglob
INPUT_FILES=("${TESTS_DIR}"/test*.in)
shopt -u nullglob

if (( ${#INPUT_FILES[@]} == 0 )); then
    printf 'ERRO:  No se encontraron test cases\n'
    exit 2
fi

for input_file in "${INPUT_FILES[@]}"; do
    test_path="${input_file%.in}"
    test_name="$(basename -- "${test_path}")"
    expected_file="${test_path}.expected"
    output_file="${test_path}.out"
    error_file="${test_path}.err"
    diff_file="${test_path}.diff"

    TOTAL=$((TOTAL + 1))

    if [[ ! -f "${expected_file}" ]]; then
        printf 'ERRO:  %s no tiene archivo .expected\n' "${test_name}"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    rm -f -- "${diff_file}"
    {
        "${PROGRAM}" < "${input_file}" > "${output_file}" 2> "${error_file}"
    } 2>/dev/null
    program_status=$?

    if (( program_status != 0 )); then
        printf 'ERRO:  %s terminó con código %d\n' "${test_name}" "${program_status}"
        if [[ ! -s "${error_file}" ]]; then
            rm -f -- "${error_file}"
        fi
        ERRORS=$((ERRORS + 1))
        continue
    fi

    if diff -u "${expected_file}" "${output_file}" > "${diff_file}"; then
        printf 'PASS:  %s\n' "${test_name}"
        rm -f -- "${diff_file}"
        PASSES=$((PASSES + 1))
    else
        printf 'FAIL:  %s\n' "${test_name}"
        FAILURES=$((FAILURES + 1))
    fi

    if [[ ! -s "${error_file}" ]]; then
        rm -f -- "${error_file}"
    fi
done

printf '\n== Resumen ===============================\n\n'
COUNT_WIDTH=${#TOTAL}
printf '%-20s %*d\n' 'Test cases:' "${COUNT_WIDTH}" "${TOTAL}"
printf '%-20s %*d\n' 'Pruebas exitosas:' "${COUNT_WIDTH}" "${PASSES}"
printf '%-20s %*d\n' 'Pruebas fallidas:' "${COUNT_WIDTH}" "${FAILURES}"
printf '%-20s %*d\n\n' 'Errores:' "${COUNT_WIDTH}" "${ERRORS}"

if (( FAILURES == 0 && ERRORS == 0 )); then
    exit 0
fi

exit 1
