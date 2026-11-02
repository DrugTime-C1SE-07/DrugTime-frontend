import type { NextRequest } from "next/server";
import { adminRoute } from "@/lib/api/client";

type Context = { params: { id: string } };
export const GET = (request: NextRequest, { params }: Context) => adminRoute(request, `/admin/drug-interactions/${params.id}`, "GET", [], params.id);
export const PATCH = (request: NextRequest, { params }: Context) => adminRoute(request, `/admin/drug-interactions/${params.id}`, "PATCH", [], params.id);
export const DELETE = (request: NextRequest, { params }: Context) => adminRoute(request, `/admin/drug-interactions/${params.id}`, "DELETE", ["expected_version"], params.id);
