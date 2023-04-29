import type { PageLoad } from './$types';
import { error } from '@sveltejs/kit';
import { findBackend } from "../../../lib/backends";

export const load = (({ params }) => {
    const backend = findBackend(params.slug);

    if (!backend) {
        throw error(404, "backend not found");
    }

    return {
        backend: backend,
    };
}) satisfies PageLoad
