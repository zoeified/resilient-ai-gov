# Resilient AI Governance

### Supporting Resource for *Governance That Grows With Your AI*

### [GRASSr00tz 2026](https://grassr00tz.com/speakers#risk-2)

---

> *"Give your AI a jacket it won't outgrow."*

---

## Purpose

This repository contains the slide deck, the Cynefin Domains Reference, the AI Governance Policy template, and the AI Registry workbook demonstrated live at GRASSr00tz 2026 during the talk **Governance That Grows With Your AI**.

The talk treats AI governance as a tailoring problem. Build a foundation that holds its shape. Determine the domain of each AI implementation. Leave room in the seams so governance can be let out as the AI evolves rather than rewritten each time a tool or technology changes.

Everything in this repository is designed to be adapted for your own organization. The Meridian Health Logistics files are fictional demo files. Replace them with your own AI implementations and the workflow remains identical.

---

## The Big Idea

> **Build governance that holds its shape as AI changes shape.**

Once you can determine which kind of problem an AI implementation puts in front of you, every governance decision has a starting point:

- What policy applies to this AI?
- How much tailoring does it need beyond the foundation?
- What controls does it inherit by domain?
- When does it need to be re-evaluated?
- Who has authority to disable it if it goes wrong?

The domain answers all of it.

---

## Repository Contents

```
resilient-ai-gov/
│
├── README.md                                                                      ← You are here
│
├── Ghostscale Presentation - GRASSR00tz - Resilient AI Governance.pdf             ← Slide deck (added after talk)
│
├── Cynefin Domains Reference.pdf                                                  ← Overview of the five domains applied to real-world events
│
├── Example Resilient AI Governance Policy.docx                                    ← Adaptable policy template with domain-based requirements
│
└── Example AI Registry.xlsx                                                       ← AI inventory, heat map scoring, Access & RBAC tracking
```

---

## How to Adapt the Materials

**Step 1: Start with the policy**

- Open `Example Resilient AI Governance Policy.docx`
- Replace `[Organization]` with your organization's name throughout
- Fill in the bracketed placeholders for policy owner, approver, dates, and authority roles
- Adapt the seeded requirements in Sections 5.1 through 5.4 to your industry and regulators

**Step 2: Inventory your AI**

- Open `Example AI Registry.xlsx`
- Replace the pre-filled Meridian examples with your actual AI implementations
- Add a row for every AI tool in your environment, including AI features enabled inside SaaS tools you already own

**Step 3: Score each implementation**

- Use the four characteristics: autonomy, explainability, adaptivity, reversibility
- Score each from 1 (ordered) to 4 (unordered)
- The workbook calculates the total, the domain, and the recommended governance move automatically

**Step 4: Apply the domain requirements**

- Each implementation inherits the foundation plus its domain's standing requirements
- The Domain Requirements tab maps directly to Section 5 of the policy

**Step 5: Record access in the RBAC tab**

- For each AI tool, record the authorized departments, the role or group controlling access, the data sensitivity allowed, and the named approver
- The AI Implementation column uses a dropdown from the Registry, so the two tabs stay in sync

---

## The Meridian Health Logistics Demo Environment

The fictional company used in this talk is **Meridian Health Logistics**, a mid-market medical logistics company that moves medical supplies and handles PHI, PII, and payment data.

Meridian is a composite designed to represent the realistic AI posture of a mid-market organization with:

- Four AI implementations spanning all four active domains
- Realistic regulatory exposure across HIPAA, PCI, and state privacy law
- A governance team facing AI adoption faster than its policy review cycle
- Vendor AI features arriving inside tools the company already owns

> **Important:** Meridian Health Logistics is entirely fictional. Any resemblance to real organizations is coincidental. All Registry entries use fabricated data for demonstration purposes only.

---

## The Five Domains

The five domains describe the kind of problem an AI implementation puts in front of your organization. Each domain calls for a different governing response.

| Domain           | What it means                                                |
| ---------------- | ------------------------------------------------------------ |
| **Clear**        | Known and ordered. Behavior is predictable and the foundation alone is sufficient. |
| **Complicated**  | Knowable with expertise. Behavior is analyzable; add expert-driven controls. |
| **Complex**      | Emergent. Behavior cannot be fully predicted and may change in response to controls; run a safe-to-fail probe. |
| **Chaotic**      | Acting without reliable explanation, in territory where consequences cannot be cleanly reversed; pre-decide authority before any incident. |
| **Undetermined** | The domain has not yet been assigned. Reliance on the implementation is prohibited until determination is complete. |

For a deeper look at the framework with applied examples drawn from real-world events, see `Cynefin Domains Reference.pdf` in this repository.

---

## The Four Characteristics

The heat map uses four characteristics to determine which domain an AI implementation belongs to.

| Characteristic     | 1 (ordered)                            | 4 (unordered)                                |
| ------------------ | -------------------------------------- | -------------------------------------------- |
| **Autonomy**       | Informs only; human takes every action | Acts independently; no human in the loop     |
| **Explainability** | Fully traceable, deterministic logic   | Black box; no reliable explanation           |
| **Adaptivity**     | Static after deployment                | Continuously learning; changes in production |
| **Reversibility**  | Fully reversible; clean undo           | Irreversible; the damage is in the world     |

Total score routes the implementation to a domain:

- **4 to 6** → Clear (the foundation alone is sufficient)
- **7 to 10** → Complicated (expert-driven controls)
- **11 to 13** → Complex (safe-to-fail probe)
- **14 to 16** → Chaotic (pre-decided authority)

Two escalation rules apply, because narrow but severe risks shall not be averaged away:

- Autonomy = 4 **and** Reversibility ≥ 3 → Chaotic regardless of total
- Adaptivity ≥ 3 **and** Explainability ≥ 3 → at least Complex regardless of total

---

## Your Monday Morning Action

You do not need a budget approval to start.

1. Pick **one** AI implementation in your environment.
2. Open the AI Registry workbook.
3. Score it on the four characteristics: autonomy, explainability, adaptivity, reversibility.
4. Read the domain it routes to.
5. Apply the foundation plus that domain's standing requirements.

---

## Related Standards and Frameworks

| Resource                          | URL                                                                     | Purpose                                                |
| --------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------ |
| Cynefin Framework                 | <https://thecynefin.co>                                                 | The sense-making model behind domain determination     |
| NIST AI Risk Management Framework | <https://www.nist.gov/itl/ai-risk-management-framework>                 | Complementary AI risk framework                        |
| ISO/IEC 42001:2023                | <https://www.iso.org/standard/81230.html>                               | AI management system standard                          |
| MITRE ATLAS                       | <https://atlas.mitre.org>                                               | Adversarial threats and tactics catalog for AI systems |
| OWASP Top 10 for LLM Applications | <https://genai.owasp.org>                                               | Application-level AI security risks                    |
| AI Security Maturity Model        | <https://cloudsecurityalliance.org/artifacts/ai-security-maturity-model>| Track maturity                                         |
| Quick Cynefin Overview Video      | <https://bit.ly/4u5Dy9H>                                                | Short 3d domain flyover to help explain each domain    |

---

## About the Speaker

**Thomas Freeman**
Director | Ghostscale
CISO Advisor | Cybersecurity Educator | Leadership Coach

🔗 [ghostscale.com](https://ghostscale.com)
🔗 [kcs.coach](https://kcs.coach)
🔗 [LinkedIn](https://www.linkedin.com/in/kustomservices/)

---

## License

The content in this repository is shared for educational purposes.
Meridian Health Logistics context files are fictional and may be freely adapted for your own use.
The policy, registry, and speaker materials may be adapted for your organization's internal use.

---

## Acknowledgments

- **Dave Snowden and the Cynefin Company** for the sense-making framework that makes this work possible
- **NIST and ISO** for foundational AI risk and management standards
- **The GRASSr00tz community** for building a security conference by practitioners, for practitioners
- **The CISO community** for the shared lessons about governing under pressure
- **Every leader who has admitted defaulting to their comfort domain.** That is the first step in fixing it.

---

> *"Measure twice, cut once."*

> *"Different problem domains require different governing responses."*

*Give your AI a jacket it won't outgrow.*
