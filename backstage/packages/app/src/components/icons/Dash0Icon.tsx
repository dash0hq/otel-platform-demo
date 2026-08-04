import SvgIcon, { SvgIconProps } from '@material-ui/core/SvgIcon';

/**
 * The Dash0 mark, for `icon: dash0` on entity links.
 *
 * Registered in App.tsx via createApp({ icons }). Backstage only resolves icon names
 * that are in that registry -- an unknown name falls back to a generic icon silently,
 * with no warning, so keep the name here and the value used in catalog-info.yaml in
 * step.
 *
 * Paths are taken verbatim from the supplied logo SVG (viewBox 0 0 140 92); only the
 * fill is changed to white.
 *
 * Note: white is fixed rather than inheriting `currentColor`, so the mark is invisible
 * against the light theme's white cards. Switch both fills to "currentColor" if it
 * needs to work in both themes.
 */
export const Dash0Icon = (props: SvgIconProps) => (
  <SvgIcon {...props} viewBox="0 0 140 92">
    <path
      d="M139.395 45.554C139.395 70.7128 119 91.108 93.8412 91.108C68.6825 91.108 48.2872 70.7128 48.2872 45.554C48.2872 20.3952 68.6825 0 93.8412 0C119 0 139.395 20.3952 139.395 45.554Z"
      fill="#FFFFFF"
    />
    <path
      d="M0 91.108C12.0817 91.108 23.6685 86.3086 32.2115 77.7656C40.7546 69.2225 45.554 57.6357 45.554 45.554C45.554 33.4723 40.7546 21.8855 32.2116 13.3425C23.6685 4.79943 12.0817 2.35239e-06 1.08609e-05 0L0 91.108Z"
      fill="#FFFFFF"
    />
  </SvgIcon>
);
