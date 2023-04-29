import type { LayoutLoad } from './$types';
import { backends } from "../../../lib/backends";

export const load = (({ params }) => {
    return {
        backends: backends,
        slug: params.slug,
    };
}) satisfies LayoutLoad
