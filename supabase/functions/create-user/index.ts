// Edge Function quản lý tài khoản (chỉ quản lý được gọi).
//   action = 'create' (mặc định) | 'set_active' | 'reset_password'
// Deploy:  supabase functions deploy create-user
// (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY được Supabase tự cấp)
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // 1) Xác thực người gọi và bắt buộc phải là quản lý
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: 'Chưa đăng nhập.' }, 401);

    const admin = createClient(url, service);
    const { data: me } = await admin
      .from('profiles').select('role, full_name').eq('id', user.id).single();
    if (me?.role !== 'manager') {
      return json({ error: 'Chỉ quản lý được thực hiện thao tác này.' }, 403);
    }

    // Ghi nhật ký thao tác (service role bỏ qua RLS)
    const audit = (action: string, entityId: string, detail: Record<string, unknown>) =>
      admin.from('audit_logs').insert({
        actor_id: user.id,
        actor_name: me.full_name,
        action,
        entity: 'account',
        entity_id: entityId,
        detail,
      });

    const b = await req.json();
    const action = String(b.action ?? 'create');

    // ---------------------------------------------------------------- create
    if (action === 'create') {
      const email = String(b.email ?? '').trim().toLowerCase();
      const password = String(b.password ?? '');
      const fullName = String(b.full_name ?? '').trim();
      const phone = b.phone ? String(b.phone).trim() : null;
      const role = String(b.role ?? '');

      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        return json({ error: 'Email không hợp lệ.' }, 400);
      }
      if (password.length < 6) {
        return json({ error: 'Mật khẩu phải có ít nhất 6 ký tự.' }, 400);
      }
      if (!fullName) return json({ error: 'Họ tên không được để trống.' }, 400);
      if (!['seller', 'production'].includes(role)) {
        return json({ error: 'Chỉ tạo được tài khoản người bán hoặc sản xuất.' }, 400);
      }

      // Trigger handle_new_user tự tạo profile (role mặc định = seller)
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, phone },
      });
      if (error) {
        const dup = /already|registered|exists/i.test(error.message);
        return json({ error: dup ? 'Email này đã được đăng ký.' : error.message }, 400);
      }

      const { error: e2 } = await admin
        .from('profiles')
        .update({ role, full_name: fullName, phone })
        .eq('id', data.user.id);
      if (e2) {
        await admin.auth.admin.deleteUser(data.user.id); // hoàn tác
        return json({ error: e2.message }, 400);
      }

      await audit('account.create', data.user.id, { name: fullName, email, role });
      return json({ id: data.user.id });
    }

    // ------------------------------------------- set_active / reset_password
    const targetId = String(b.id ?? '');
    if (!targetId) return json({ error: 'Thiếu id tài khoản.' }, 400);
    if (targetId === user.id) {
      return json({ error: 'Không thể thao tác trên chính tài khoản của bạn.' }, 400);
    }
    const { data: target } = await admin
      .from('profiles').select('role, full_name').eq('id', targetId).single();
    if (!target) return json({ error: 'Không tìm thấy tài khoản.' }, 404);
    if (target.role === 'manager') {
      return json({ error: 'Không thao tác được trên tài khoản quản lý.' }, 403);
    }

    if (action === 'set_active') {
      const active = b.active === true;
      // ban_duration: khoá ~100 năm / 'none' = mở khoá
      const { error } = await admin.auth.admin.updateUserById(targetId, {
        ban_duration: active ? 'none' : '876000h',
      });
      if (error) return json({ error: error.message }, 400);
      const { error: e2 } = await admin
        .from('profiles').update({ is_active: active }).eq('id', targetId);
      if (e2) return json({ error: e2.message }, 400);
      await audit(active ? 'account.unlock' : 'account.lock', targetId, {
        name: target.full_name,
        role: target.role,
      });
      return json({ ok: true });
    }

    if (action === 'reset_password') {
      const password = String(b.password ?? '');
      if (password.length < 6) {
        return json({ error: 'Mật khẩu phải có ít nhất 6 ký tự.' }, 400);
      }
      const { error } = await admin.auth.admin.updateUserById(targetId, { password });
      if (error) return json({ error: error.message }, 400);
      await audit('account.reset_password', targetId, {
        name: target.full_name,
        role: target.role,
      });
      return json({ ok: true });
    }

    return json({ error: 'Hành động không hợp lệ.' }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});