import { useEffect, useState } from 'react';
import { useAuth } from '@/context/AuthContext';
import { supabase } from '@/lib/supabase';
import { useMyProfile } from './useMyProfile';

export interface OnlineUser {
  userId: string;
  username: string;
}

export function useRoomPresence(roomId: string | undefined): OnlineUser[] {
  const { user } = useAuth();
  const { data: profile } = useMyProfile();
  const [online, setOnline] = useState<OnlineUser[]>([]);

  useEffect(() => {
    if (!roomId || !user) return undefined;

    const channel = supabase.channel(`presence-${roomId}`, {
      config: { presence: { key: user.id } },
    });

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState<{ username: string }>();
        const list = Object.entries(state).map(([userId, metas]) => ({
          userId,
          username: metas[0]?.username ?? 'Alguém',
        }));
        setOnline(list);
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({ username: profile?.username ?? 'Você' });
        }
      });

    return () => {
      supabase.removeChannel(channel);
    };
  }, [roomId, user, profile?.username]);

  return online;
}
