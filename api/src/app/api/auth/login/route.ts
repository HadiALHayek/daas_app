import { NextRequest } from "next/server";
import { getAnonClient } from "@/lib/supabase";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return Response.json(
        { error: "البريد الإلكتروني وكلمة المرور مطلوبان" },
        { status: 400 }
      );
    }

    const supabase = getAnonClient();
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error || !data.session) {
      return Response.json(
        { error: "بيانات الدخول غير صحيحة" },
        { status: 401 }
      );
    }

    return Response.json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
      user: { id: data.user?.id, email: data.user?.email },
    });
  } catch (e) {
    return Response.json(
      { error: e instanceof Error ? e.message : "خطأ" },
      { status: 500 }
    );
  }
}
