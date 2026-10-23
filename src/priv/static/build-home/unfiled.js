// Shared display rules for planning-pack rows, including their pre-filing identity.
export const isUnfiled = t => t.num == null && t.src?.kind === 'pack';
export const refText = t => isUnfiled(t) || !Number.isFinite(t.num) ? '—' : '#' + t.num;
export const refTitle = t => isUnfiled(t) ? 'Not filed yet' : refText(t);
export const queueText = t => isUnfiled(t) ? 'Not filed' : t.qpos == null ? 'Q?' : 'Q' + t.qpos;
export const srcLine = t => t.src.path + (t.src.wave != null ? ' · wave ' + t.src.wave : '') + ' · not filed yet';
export const srcTitle = t => 'From ' + t.src.path + (t.src.wave != null ? ' · wave ' + t.src.wave : '');
export const findWas = (rows, id) => rows.find(row => row.was === id) || null;
