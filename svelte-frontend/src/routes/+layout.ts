import type { LayoutLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load = (({ url, params }) => {
    if (url.pathname.indexOf("/backend") === 0 && params.slug) {
        return;
    }
    throw redirect(303, `/backend/rust`);
}) satisfies LayoutLoad
