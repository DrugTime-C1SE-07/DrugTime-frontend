import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

export const GET = (request: NextRequest) => adminRoute(request, "/admin/drug-food-interactions", "GET", ["q", "ingredient_id", "medication_id", "severity_level", "skip", "limit"]);
export const POST = (request: NextRequest) => adminRoute(request, "/admin/drug-food-interactions", "POST");
