import { NextRequest } from "next/server";
import { getAdminClient, getAnonClient } from "@/lib/supabase";
import { unauthorized, badRequest, serverError } from "@/lib/auth";

export async function POST(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return unauthorized();
  }
  const token = authHeader.slice(7);

  try {
    const admin = getAdminClient();
    const { data: userData, error: userError } = await admin.auth.getUser(
      token
    );
    if (userError || !userData.user?.email) {
      return unauthorized();
    }

    const body = await request.json();
    const currentPassword = body.current_password;
    const newPassword = body.new_password;

    if (!currentPassword || !newPassword) {
      return badRequest("كلمة المرور الحالية والجديدة مطلوبتان");
    }
    if (String(newPassword).length < 6) {
      return badRequest("يجب أن تكون كلمة المرور 6 أحرف على الأقل");
    }

    // Re-verify the current password before allowing a change.
    const anon = getAnonClient();
    const { error: signInError } = await anon.auth.signInWithPassword({
      email: userData.user.email,
      password: String(currentPassword),
    });
    if (signInError) {
      return Response.json(
        { error: "كلمة المرور الحالية غير صحيحة" },
        { status: 401 }
      );
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      userData.user.id,
      { password: String(newPassword) }
    );
    if (updateError) {
      return serverError(updateError.message);
    }

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
