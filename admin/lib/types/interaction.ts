export type InteractionSeverity = "contraindicated" | "major" | "moderate" | "minor";

export type InteractionMechanismType = "pk" | "pd" | "both" | "unknown";

export type InteractionEvidenceLevel = "clinical" | "case_report" | "in_vitro" | "theoretical";

export type InteractionStatus = "verified" | "pending";

export type InteractionTargetType = "drug_drug" | "drug_food";

export interface Interaction {
  id: string;
  ruleCode: string; // VD: RULE-INT-0418
  drugA: string;
  drugB: string;
  drugAClass?: string;
  drugBClass?: string;
  atcCodeA?: string; // VD: B01AA03
  atcCodeB?: string; // VD: M01AE01
  targetType: InteractionTargetType; // drug_drug hoặc drug_food
  severity: InteractionSeverity;
  mechanismType: InteractionMechanismType;
  mechanism: string;
  clinicalEffect: string;
  management: string;
  evidenceLevel: InteractionEvidenceLevel;
  source: string;
  originSource?: string; // VD: QĐ 5948/QĐ-BYT (Mục 4.2)
  crossReference?: string; // VD: DrugBank: DB00682
  verifiedBy?: string; // VD: DS. Lê Minh Trí
  status: InteractionStatus;
  updatedAt: string;
  notes?: string;
  isDeleted?: boolean;
}

export type InteractionFilterState = {
  search: string;
  severity: string;
  mechanismType: string;
  targetType: string;
  status: string;
};
