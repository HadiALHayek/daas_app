import { NextRequest } from "next/server";
import { getAnonClient } from "@/lib/supabase";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { refresh_token } = body;

    if (!refresh_token) {
      return Response.json(
        { error: "refresh_token مطلوب" },
        { status: 400 }
      );
    }

    const supabase = getAnonClient();
    const { data, error } = await supabase.auth.refreshSession({
      refresh_token,
    });

    if (error || !data.session) {
      return Response.json(
        { error: "انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى." },
        { status: 401 }
      );
    }

    return Response.json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
    });
  } catch (e) {
    return Response.json(
      { error: e instanceof Error ? e.message : "خطأ" },
      { status: 500 }
    );
  }
}
