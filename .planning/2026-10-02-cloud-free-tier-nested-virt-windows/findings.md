# Findings: Free-tier cloud + nested virtualization + 2 VMs Windows

Fecha de corte: octubre 2026.

## PREGUNTA CENTRAL — Nested virtualization

### OCI — ARM no soporta nested virt
[OFICIAL] Blog Oracle Linux (2025), https://blogs.oracle.com/linux/kvm-nested-virtualization-in-oci
> Shape: `AMD: VM.Standard.E5.Flex` o `Intel: VM.Standard3.Flex` (**Ampere VMs (ARM/aarch64) did not support nested virtualization**)

[OFICIAL] OCI Docs Compute Shapes, https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm
- `VM.Standard.A1.Flex`: "**Windows images are not supported on this shape.**" (columna Max VNICs Total: Windows)
- `VM.Standard.A2.Flex`, `VM.Standard.A4.Flex`, `VM.Standard.A4.Ax.Flex`: "Windows images are not supported on this shape."
- `VM.Standard.E2.1.Micro`: 1 OCPU, memoria → Always Free Resources, 1 VNIC Linux, **"-" en Max VNICs Total: Windows**
  → CORROBORACIÓN CRUZADA: E2.1.Micro no soporta imágenes Windows.

### OCI — Windows no soportado en shapes ARM (doc de resize)
[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/resizinginstances.htm
> "Ampere: ... The `VM.Standard.A1.Flex` shape is an Always Free shape. **These shapes are not supported for Windows.**"

### OCI — VirtualBox en OCI requiere Intel
[OFICIAL] https://docs.oracle.com/en/learn/ol-vbox/
> "If you're installing on an OCI instance, you'll need to use an Intel CPU shape such as VM.Standard3.Flex."

### OLCNE — nested virt no disponible en instancias ARM virtuales
[OFICIAL] https://docs.oracle.com/en/operating-systems/olcne/1.9/quickinstall/hosts.html
> "Nested virtualization is needed on virtual hosts to create virtual machines using the KubeVirt module... **Nested virtualization isn't available on virtual ARM instances.**"

### Historial: doc OCI-KVM 2018 decía que AMD no soportaba nested virt
[OFICIAL] https://docs.oracle.com/en-us/iaas/oracle-linux/oci/index.htm
> "AMD processor-based virtual machines do not support nested virtualization" (documento EOL, 2018/2019)
→ CONTRADICCIÓN con el blog 2025. Doc actual ganada por el blog 2025 (AMD E5.Flex). Marcar como evolución documental.

### CONCLUSIÓN PRELIMINAR (a confirmar con Always Free page)
- Las 2 shapes Always Free de OCI son A1.Flex (ARM, sin Windows, sin nested virt) y E2.1.Micro (AMD, 1 OCPU/1 GB, sin Windows).
- Ninguna de las dos admite Windows → **cuello de botella #1 ya identificado**.

## OCI — Always Free Resources (doc oficial)
[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

### Compute
- **E2.1.Micro (AMD):** hasta **2 instancias** gratis.
  - Processor: **1/8 de OCPU** (con capacidad de usar CPU adicional por bursting)
  - Memory: **1 GB**
  - Networking: 1 VNIC, 1 public IP, 50 Mbps internet / 480 Mbps regional
  - **Images Always Free-eligible: SOLO Oracle Linux, Ubuntu, CentOS, Oracle Linux Cloud Developer. NO Windows.**
- **A1.Flex (ARM):** 1.500 OCPU-hours y 9.000 GB-hours/mes gratis
  - **"For Always Free tenancies, this is equivalent to 2 OCPUs and 12 GB of memory."**
  - ⚠️ **CORRECCIÓN A LA PREMISA DEL USUARIO**: ya NO es 4 OCPU / 24 GB. La doc oficial vigente dice **2 OCPU / 12 GB total**. Verificar con fuente secundaria si hubo reducción.
  - "you can create one or two ... A1 Compute instances, **2 OCPUs total**"
  - Images: Oracle Linux, Ubuntu, Oracle Linux Cloud Developer. **NO Windows.**

### Regla que mata el caso Windows
[OFICIAL] misma URL, Tip:
> "The Linux images labeled 'Always Free Eligible' ... are compatible with Always Free compute instances and **incur no licensing fees**. ... **To provision a compute instance with an image that is not Always Free-eligible, you must have a paid account or a Free Trial account with available credits.**"

### Block Volume
- **200 GB totales** Always Free (boot + block combinados, en home region)
- **5 volume backups**
- Boot volume por defecto 50 GB (min 50 GB → 4 instancias consumen los 200 GB). En otra sección del mismo doc dice "minimum boot volume size for each instance is **47 GB**" → INCONSISTENCIA interna del doc Oracle (47 vs 50).

### Idle Compute Reclamation (CRÍTICO para "persistente")
[OFICIAL] misma URL, sección "Idle Compute Instances":
> "**Idle Always Free compute instances may be reclaimed by Oracle.**" Si en un período de 7 días: CPU 95th percentile <20%, red <20%, memoria <20% (solo A1).
→ Riesgo real de que el laboratorio sea **apagado destruido** por Oracle. Esto vulnera el requisito de "persistente".

### Always Free = solo en home region
[OFICIAL] misma URL: "You must create the Always Free compute instances in your **home region**."

## OCI — Confirmación de la reducción de A1 (4/24 → 2/12)
[COMUNIDAD] https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/ (2026-07-03)
> "Oracle has reduced the Always Free Ampere A1 Compute allowance on Oracle Cloud Infrastructure **from 4 OCPUs and 24 GB of RAM to 2 OCPUs and 12 GB of RAM. The change took effect on June 15, 2026.**" Sin anuncio público; solo se actualizó la doc.

[COMUNIDAD] https://community.oracle.com/customerconnect/discussion/970310/oci-always-free-updated-ampere-a1-compute-allocation (2026-07-21)

[COMUNIDAD] https://community.oracle.com/customerconnect/discussion/974451/always-free-a1-disabled-need-re-enable-to-resize-4-ocpu-24gb-to-2-ocpu-12gb
> Instancias existentes con 4/24 quedaron **"Instance is disabled and will not accept any action requests"**.

⚠️ [COMUNIDAD] Reportes de que el soporte de Oracle dice que el límite 2/12 aplica **solo a cuentas free-only**, y que PAYG conserva 4/24 sin cargo. La doc oficial **no distingue** entre tipos de cuenta. Marcar como HIPÓTES no confirmada por Oracle.

## OCI — Licencias Windows: SEGUNDO CUELLO DE BOTELLA
[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/Compute/References/microsoftlicensing.htm
> "**Important: Microsoft bring your own license is not available on Free Tier or trial tenancies.**"
> - "OCI Provided: OCI provides the Windows Server licenses ... **for a fee**"
> - "Billing for the Windows Server license is based on **per-OCPU, per-second** usage."
> - "Bring your own Hyper-V | Issued by Oracle | **Instances must be launched on a dedicated host**" (bare metal) → no es gratis.

[OFICIAL] https://www.oracle.com/cloud/compute/faq/
> "On April 25, 2020, Oracle Cloud Infrastructure changed the pricing of Windows licenses to **$0.092 per OCPU/hr**."
> Tabla: Windows Server en VM multi-tenant shared host → BYOL "**Not eligible**. Shared hosts must use Oracle-provided images that include the Microsoft license."

[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/Compute/References/bringyourownimage.htm
> Windows Server editions disponibles (Server, NO Windows 10): 2016 / 2019 / 2022 / 2025 — Datacenter, Standard, Standard Core. **"Importing your own ISO image is not supported."**

→ **CONCLUSIÓN OCI (verificada):**
1. A1.Flex = ARM/aarch64 → sin Windows, sin nested virt.
2. E2.1.Micro = AMD 1/8 OCPU + 1 GB → sin Windows (solo imágenes Linux Always Free-eligible), 1 GB insuficiente.
3. BYOL **prohibido en Free Tier** → imposible usar licencia propia.
4. Licencia Windows OCI-provided = **$0.092/OCPU-h** → costo ≠ 0.
5. Aunque se pagara, E2.1.Micro (1/8 OCPU) no puede correr Windows ni 2 VMs anidadas.

**OCI NO CUMPLE. Ninguna de sus 2 shapes Always Free admite Windows, y ninguna admite nested virtualization.**

## AWS — Free Tier (cambió en 2025)
[OFICIAL] https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/ (2025-07-01, blog 2025-07-15)
> "$100 in AWS credits upon sign-up + up to $100 more"; **free account plan expira a los 6 meses o al agotar créditos**.

[OFICIAL] https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html
Tabla oficial antes/después del 15-jul-2025:
| Beneficio | Cuenta antes 2025-07-15 | Cuenta desde 2025-07-15 |
|---|---|---|
| Instancias free | `t2.micro`, `t3.micro` | `t3.micro`, `t3.small`, `t4g.micro`, `t4g.small`, **`c7i-flex.large`, `m7i-flex.large`** |
| Duración | 12 meses | **6 meses o hasta agotar créditos** |

[OFICIAL] https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier.html
> "**Paid plan accounts might have `Short-term trial` and `Always Free` offerings active. Free account plan only have `Always Free` offerings active.**"
> EC2 aparece como "Use **credits** to access features in both Free and Paid plans" → **EC2 NO es always-free, es crédito temporal**.
→ **No existe EC2 gratis permanente en AWS.** Los "always free" de AWS (30+ servicios) no incluyen EC2.

## AWS — Nested virtualization (LANZAMIENTO FEB 2026, NUEVO)
[OFICIAL] https://aws.amazon.com/about-aws/whats-new/2026/02/amazon-ec2-nested-virtualization-on-virtual/ (2026-02-01)
> "Previously, customers could only create and manage virtual machines inside **bare metal** EC2 instances."

[OFICIAL] https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html
> Tipos soportados: **C8i, M8i, R8i, C8id, R8id, M8id, C8i-flex, R8i-flex, M8i-flex, X8i, C7i, R7i, M7i, C7i-flex, M7i-flex, I7i**
> Hypervisores L1 soportados: KVM y Hyper-V.
> "When nested virtualization is enabled on a Windows instance: Credential Guard – Virtual Secure Mode (VSM) is automatically disabled."

⚠️ **HALLAZGO CLAVE**: `c7i-flex.large` y `m7i-flex.large` están (a) en la lista de nested virtualization y (b) en la lista de free-tier eligible. PERO el free tier es de **6 meses con créditos**, no permanente, y son **x86-64 pagados**.

[COMUNIDAD] re:Post 2024 (histórico): "Most EC2 instances are VMs that don't support nested virtualization. To get access to the bare hardware, you need a metal instance type." → Antes de feb-2026 era NO; ahora sí, pero en familias grandes.

## GCP — Nested virtualization (VEREDICTO NEGATIVO para e2-micro)
[OFICIAL] https://docs.cloud.google.com/compute/docs/instances/nested-virtualization/overview
> "You can't use the following VMs:
> - **E2 VMs**
> - VMs powered by ARM processors
> - VMs powered by AMD processors **except N4D** which does support nested virtualization"
> Hypervisor L1 soportado: **solo Linux KVM** (Hyper-V no).
> CPU platform mínima Intel Haswell.

→ **e2-micro NO soporta nested virtualization. Verificado oficialmente.**

[COMUNIDAD] StackOverflow 59367377: intento con e2-micro → "INFO: Your CPU does not support KVM extensions / KVM acceleration can NOT be used". Funciona con n1-standard-1. `e2-standard-2` → ERROR: "Setting minimum CPU platform is not supported for the selected machine type".

## AZURE — Nested virtualization (VEREDICTO NEGATIVO para free tier)
[OFICIAL] https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/ddv4-series → tabla "Feature support": **Nested Virtualization: Supported** (Ddv4/Ddsv4, mínimo Standard_D2d_v4)
[OFICIAL] https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/ddsv6-series → "Nested Virtualization: Supported" (mín. Standard_D2ds_v6, 2 vCPU/8 GiB)
[OFICIAL] https://azure.microsoft.com/en-us/blog/nested-virtualization-in-azure/ (2017) → arrancar con **Dv3 y Ev3**.

[COMUNIDAD] Microsoft Q&A (empleado MS, Benjamin Guinebertière, 2024): series con nested virt = D_v3, Ds_v3, Dv4, Dsv4, Ddv4, Ddsv4, E_v3, Es_v3, Ev4, Esv4, Edv4, Edsv4, F2s_v2–F72s_v2, FX4–FX48, M.

→ **Ninguna serie B (B1s/B2s) soporta nested virtualization.** Azure free tier (750 h B1s/B2s) → **NO CUMPLE**.

## GCP — Free Tier oficial
[OFICIAL] https://docs.cloud.google.com/free/docs/free-cloud-features
Tabla Free Tier, fila Compute Engine:
> "**1 non-preemptible `e2-micro` VM instance per month** in one of the following US regions: Oregon:`us-west1`. Iowa:`us-central1`. South Carolina:`us-east1`. **30 GB-months standard persistent disk.** 1 GB outbound..."
> "Your Free Tier `e2-micro` instance limit is by time, not by instance. ... Usage calculations are combined across the supported regions."

e2-micro = **0.25 vCPU (shared-core, burst a 2), 1 GB RAM**. [COMUNIDAD] tabla de https://kindatechnical.com/... y doc de E2 en GCP.
⚠️ "limit is by time, not by instance" → se pueden crear varias, pero el total de horas seCombina. Un mes = ~730 h como máximo.
→ **1 VM pequeña. 0.25 vCPU / 1 GB. Imposible 2 VMs Windows, y sin nested virt.**

[OFICIAL] https://cloud.google.com/free → "There is no charge to use these products up to their specified free usage limit. **The free usage limit does not expire**, but is subject to change."

## GCP — Licencia Windows
[OFICIAL] https://cloud.google.com/compute/disks-image-pricing (y /compute/pricing)
> "Windows Server images ... **f1-micro and g1-small machine types: $0.023 USD/hour. All other machine types: $0.046 USD/hour per visible vCPU.**"
→ e2-micro no es f1/g1 → costo ≠ 0.
[OFICIAL] https://docs.cloud.google.com/compute/docs/instances/windows/ms-licensing
> "Windows Server licenses are **typically not eligible for BYOL using License Mobility**, but might be eligible for BYOL by Outsourcing Software Management Rights." (con condiciones; no aplica a Windows 10 client).

## AZURE — Free Tier oficial
[OFICIAL] https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services
> "your Azure free account includes access to three types of VMs for free—the **B1S, B2pts v2 (ARM-based), and B2ats v2 (AMD-based)** burstable VMs that are usable for **up to 750 hours per month**."
> "For example, you get **750 hours of a B1S Windows virtual machine free each month**... **You can create 5 B1S Windows virtual machines and use them for 150 hours each.**"
→ Windows license **incluida** en el free tier de Azure (12 meses).

[OFICIAL] https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account → "Free monthly amounts of 20+ popular services **for 12 months**" + "65+ always-free services". $200 crédito 30 días.

[COMUNIDAD] https://marketplace.microsoft.com/en-us/product/azure-services/microsoft.freeaccountvirtualmachine → "750 hours of Standard B1, B2ATS, and B2PTS **Linux**" + "750 hours ... **Windows**" + "2 P6 (64GiB) managed disks"

⚠️ **LÍMITE CUANTITATIVO DECISIVO (aplica a GCP legacy, Azure, y AWS legacy):**
750 h/mes NO alcanza para 2 VMs siempre encendidas (2 × ~730 h = **1.460 h/mes**). Azure solo da 750 h. Con 750 h se pueden correr 2 VMs **375 h c/u**, no simultáneas 24/7.

## OTROS PROVEEDORES — sin free tier permanente
[COMUNIDAD] https://klymentiev.com/blog/free-vps (2026-09-11)
> "**Two providers give a genuinely free, always-on VPS with no expiry: Oracle Cloud Always Free and Google Cloud free tier.** Everything else marketed as a free VPS is a time-limited trial or a credit grant."
Tabla del artículo:
| Proveedor | Specs | Duración | Tarjeta |
|---|---|---|---|
| OCI Always Free | 2 cores Arm Ampere + 12 GB (o 2 micro VMs AMD), 200 GB, 10 TB/mes | **Siempre gratis** | Sí |
| GCP free tier | 1 e2-micro, 30 GB | **Siempre gratis** | Sí |
| AWS Free Tier | $200 créditos (nuevo) / t3.micro 750 h (legado) | 6 meses / 12 meses | Sí |
| DigitalOcean | $200 créditos, 60 días | temporal | Sí |
| Vultr | $100–300 créditos promo | temporal | Sí |
| Linode (Akamai) | $100 créditos, 60 días | temporal | Sí |
| Hetzner | **ninguno** | — | — |

[COMUNIDAD] https://agentdeals.dev/digitalocean-free-tier-2026 → "**There is no perpetual free compute** — after credits expire, the cheapest Droplet is **$4/month**". Free permanente = 3 static sites + Functions serverless + DNS.
[COMUNIDAD] https://www.digitalocean.com/resources/articles/hetzner-alternatives → Hetzner CX desde €3.49-5.49/mes; sin free tier. Linode Nanode desde $5/mes. Vultr desde $5/mes.

**Ninguno de los 4 ofrece free tier permanente.** Confirmado.

## BÚSQUEDA NEGATIVA: ¿existe free tier con nested virtualization?
- Hetzner: [COMUNIDAD] https://www.frankchiarulli.com/blog/nix-pvm/ → "**Hetzner Cloud doesn't [support nested virt], on any tier. No nested virtualization, no /dev/kvm, no microVM.**"
- DigitalOcean: [COMUNIDAD] tabla de compatibilidad → "**DigitalOcean | No | Not available on standard droplets**"
- Vultr: solo bare metal (pagado).
- OCI: solo E5.Flex/Standard3.Flex y Bare Metal → pagados.
- AWS: C7i/M7i/etc. → pagados (o créditos 6 meses).
- GCP: solo N2/N4D y superiores → pagados.
- Azure: solo Dv3+ → pagados.

[COMUNIDAD] https://github.com/volkertb/cicd-qemu-dos-docker/issues/1 → **GitHub Actions**: "these new runners **also add support for nested virtualization**, which will allow hypervisors such as QEMU to run in GitHub Actions much faster, since it will no longer have to resort to CPU emulation in software". ⚠️ PERO: runners de GitHub son **efímeros por job**, no persistentes.

## AWS — Licencia Windows + EBS
[OFICIAL] https://aws.amazon.com/ec2/pricing/on-demand/
> "The savings for using Windows Server AMIs is **$0.046 per vCPU-hour**" (AWS Optimize CPUs, tabla RunInstances:0002)
[OFICIAL] https://docs.aws.amazon.com/prescriptive-guidance/latest/optimize-costs-microsoft-workloads/right-ec2-instance.html
> Tabla: r5.xlarge Windows Server (LI) → compute $183.96 + **Windows license $134.32** → total $318.28.
[OFICIAL] https://aws.amazon.com/ebs/pricing/
> "AWS Free Tier includes **30 GB of storage, 2 million I/Os, and 1 GB of snapshot storage** with Amazon EBS."

## OCI — Tarjeta de crédito y riesgo de cargos
[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm
> "most users need a mobile phone number and a **credit card** to create an account. **Your credit card will not be charged unless you upgrade your account.**"
[OFICIAL] https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/changingpaymentmethod.htm
> "When you sign up for the Free Tier, your credit card is **authorized for $1 USD** at the time of sign-up." (Al hacer upgrade: **$100 USD**.) "the credit card authorizations are immediately reversed on the Oracle side."
[OFICIAL] https://www.oracle.com/cloud/free/faq/
> "Oracle may periodically check the validity of your card, resulting in a temporary 'authorization' hold. These holds are removed by your bank, typically within three to five days, and **do not result in actual charges**."
> **"Oracle Cloud Free Tier does not include SLAs... Customers using only Always Free resources are not eligible for Oracle Support."**
> Excepción sin tarjeta: usuarios reconocidos de Oracle (Oracle Academy, CloudWorld, clientes de Sales) pueden registrarse sin tarjeta. [OFICIAL] blog Oracle Apex.

## PENDIENTE (últimos)
- Colab / Kaggle: ¿nested virt? ¿persistencia?
- GitHub Actions larger runners: gratis para repos públicos + nested virt, pero efímeros