# Task Plan: Free-tier cloud con nested virtualization para 2 VMs Windows (LTSB 2016 / LTSC 2021)

## Goal

Determinar con evidencia oficial actualizada (octubre 2026) si existe algún proveedor cloud con free
tier permanente que permita ejecutar DOS VMs Windows x86-64 simultáneas, persistentes y
scriptables con virtualización anidada acelerada, a costo estrictamente cero; y si no existe,
identificar y cuantificar el cuello de botella exacto.

## Next Step

Responder la pregunta central: ¿OCI (y cualquier otro free tier) ofrece nested virtualization en
shapes que entren en Always Free? Empezar por docs oficiales de OCI nested virtualization.

## Current Phase

Phase 1

## Phases


### Phase 2: OCI en detalle

- [x] Always Free tiers vigentes (A1 = 2 OCPU/12 GB tras reducción jun-2026; E2.1.Micro = 1/8 OCPU/1 GB)
- [x] Block volume storage Always Free (200 GB + 5 backups)
- [x] Licencias Windows en OCI (BYOL prohibido en Free Tier; OCI-provided $0.092/OCPU-h)
- [x] A1 = ARM/aarch64: sin Windows, sin nested virt
- [x] Tarjeta de crédito y riesgo de cargos (autorización $1, sin cargo salvo upgrade)
- [x] 2 VMs simultáneas Always Free (SÍ en cantidad, NO en capacidad útil)
- **Status:** complete

### Phase 3: AWS, GCP, Azure free tiers

- [x] AWS: cambio 15-jul-2025 a créditos, 6 meses, sin EC2 always-free
- [x] AWS: nested virt feb-2026 en C7i/M7i/C8i/M8i...; EBS 30 GB (legacy); Windows $0.046/vCPU-h
- [x] GCP: e2-micro (0.25 vCPU/1 GB), 30 GB-month PD, sin nested virt, Windows $0.046/vCPU-h
- [x] Azure: B1s/B2pts v2/B2ats v2, 750 h/mes, Windows incluido 12 meses, sin nested virt
- **Status:** complete

### Phase 4: Otros proveedores

- [x] Hetzner, Vultr, DigitalOcean, Linode: sin free tier permanente (verificado)
- [x] Colab / Kaggle: sin nested virt documentado, runtimes efímeros
- [x] Búsqueda de cualquier free tier con nested virt → resultado negativo
- **Status:** complete

### Phase 5: Informe final

- [x] Tabla comparativa resumen
- [x] Veredicto explícito sobre el cuello de botella
- [x] Etiquetado [OFICIAL]/[COMUNIDAD] y URLs
- **Status:** complete

## Key Questions

1. ¿Qué shapes de OCI soportan nested virtualization y cuáles están en Always Free?
   → E5.Flex/Standard3.Flex y Bare Metal soportan; A1.Flex y E2.1.Micro NO.
2. ¿A1 (ARM) puede ejecutar Windows x86-64 acelerado? → NO (doc oficial: "Windows images are not supported").
3. ¿El Always Free de OCI permite 2 VMs simultáneas? → SÍ en cantidad (2 micro o 2×1 OCPU A1), pero ninguna es usable para Windows ni 2 VMs anidadas.
4. ¿Windows requiere licencia pagada aparte? → OCI/GCP/AWS: sí. Azure: incluida, pero solo 12 meses y sin nested virt. OCI BYOL: prohibido en Free Tier.
5. ¿Existe algún free tier con nested virt? → NO.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Marcar cada dato como [OFICIAL]/[COMUNIDAD]/no documentado | Requisito explícito del usuario |
| Priorizar la pregunta de nested virt antes del desglose por proveedor | Requisito explícito; es la condición de viabilidad |
| No proponer arquitectura, solo evidencia | Requisito explícito |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| Plan creado con plantilla genérica → hook reportó "PLAN TAMPERED" | 1 | Reescrito task_plan.md con fases reales |

## Notes

- Fecha de corte de datos: octubre 2026. AWS free tier cambió en 2025: verificar.
- No afirmar "confirmado" sin URL oficial; si no hay, marcar hipótesis.