import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

export const GET = (request: NextRequest) => adminRoute(request, "/admin/medications", "GET", ["q", "skip", "limit"]);
export const POST = (request: NextRequest) => adminRoute(request, "/admin/medications", "POST");
