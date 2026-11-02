import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

export const GET = (request: NextRequest) => adminRoute(request, "/admin/drug-interactions", "GET", ["q", "ingredient_id", "medication_id", "interaction_type", "severity_level", "skip", "limit"]);
export const POST = (request: NextRequest) => adminRoute(request, "/admin/drug-interactions", "POST");
