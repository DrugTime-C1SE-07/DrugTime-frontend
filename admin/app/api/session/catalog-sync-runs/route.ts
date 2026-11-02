import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

export const GET = (request: NextRequest) => adminRoute(request, "/admin/catalog/sync-runs", "GET", ["source", "status", "offset", "limit"]);
