import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

export const GET = (request: NextRequest) => adminRoute(request, "/admin/active-ingredients", "GET", ["q", "medication_id", "skip", "limit"]);
