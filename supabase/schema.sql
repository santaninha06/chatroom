-- ChatRoom: esquema do banco

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  avatar_color text not null default '#2563EB',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Perfis: leitura para quem está logado"
  on public.profiles for select to authenticated using (true);

create policy "Perfis: atualizar o próprio"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

grant select, update on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, avatar_color)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(new.email, '@', 1)
    ),
    (array['#2563EB', '#7C3AED', '#DB2777', '#059669', '#D97706', '#DC2626', '#0891B2'])
      [1 + floor(random() * 7)]
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 60),
  description text not null default '',
  emoji text not null default '💬',
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;

create policy "Salas: leitura para quem está logado"
  on public.rooms for select to authenticated using (true);

create policy "Salas: criar como dono"
  on public.rooms for insert to authenticated
  with check (auth.uid() = created_by);

grant select, insert on public.rooms to authenticated;

create table public.room_members (
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

alter table public.room_members enable row level security;

create or replace function public.is_room_member(p_room_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = auth.uid()
  );
$$;

revoke all on function public.is_room_member(uuid) from public;
grant execute on function public.is_room_member(uuid) to authenticated;

create policy "Membros: a própria linha e os colegas de sala"
  on public.room_members for select to authenticated
  using (user_id = auth.uid() or public.is_room_member(room_id));

create policy "Membros: entrar como eu mesmo"
  on public.room_members for insert to authenticated
  with check (user_id = auth.uid());

create policy "Membros: sair (apagar a própria linha)"
  on public.room_members for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, delete on public.room_members to authenticated;

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index messages_room_idx
  on public.messages (room_id, created_at);

alter table public.messages enable row level security;

create policy "Mensagens: ler as das salas em que estou"
  on public.messages for select to authenticated
  using (public.is_room_member(room_id));

create policy "Mensagens: enviar nas salas em que estou"
  on public.messages for insert to authenticated
  with check (user_id = auth.uid() and public.is_room_member(room_id));

create policy "Mensagens: apagar as próprias"
  on public.messages for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, delete on public.messages to authenticated;

alter publication supabase_realtime add table public.messages;
