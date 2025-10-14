import { Navigate, Route } from 'react-router-dom';
import { apiDocsPlugin, ApiExplorerPage } from '@backstage/plugin-api-docs';
import {
  CatalogEntityPage,
  CatalogIndexPage,
  catalogPlugin,
} from '@backstage/plugin-catalog';
import {
  CatalogImportPage,
  catalogImportPlugin,
} from '@backstage/plugin-catalog-import';
import { ScaffolderPage, scaffolderPlugin } from '@backstage/plugin-scaffolder';
import { orgPlugin } from '@backstage/plugin-org';
import { SearchPage } from '@backstage/plugin-search';
import {
  TechDocsIndexPage,
  techdocsPlugin,
  TechDocsReaderPage,
} from '@backstage/plugin-techdocs';
import { TechDocsAddons } from '@backstage/plugin-techdocs-react';
import { ReportIssue } from '@backstage/plugin-techdocs-module-addons-contrib';
import { UserSettingsPage } from '@backstage/plugin-user-settings';
import { apis } from './apis';
import { entityPage } from './components/catalog/EntityPage';
import { searchPage } from './components/search/SearchPage';
import { Root } from './components/Root';

import {
  AlertDisplay,
  OAuthRequestDialog,
  SignInPage,
} from '@backstage/core-components';
import { createApp } from '@backstage/app-defaults';
import { AppRouter, FlatRoutes } from '@backstage/core-app-api';
import { CatalogGraphPage } from '@backstage/plugin-catalog-graph';
import { RequirePermission } from '@backstage/plugin-permission-react';
import { catalogEntityCreatePermission } from '@backstage/plugin-catalog-common/alpha';
import { NotificationsPage } from '@backstage/plugin-notifications';
import { SignalsDisplay } from '@backstage/plugin-signals';
import { createUnifiedTheme, genPageTheme, UnifiedThemeProvider, palettes } from '@backstage/theme';

const customTheme = createUnifiedTheme({
  palette: {
    ...palettes.dark,
    primary: {
      main: '#f9503c',
      light: '#fa9266',
      dark: '#e63e28',
    },
    background: {
      default: '#18181b',
      paper: '#1f1f22',
    },
    navigation: {
      ...palettes.dark.navigation,
      background: '#1f1f22',
    },
  },
  defaultPageTheme: 'home',
  pageTheme: {
    home: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    documentation: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    tool: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    service: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    website: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    library: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    other: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    app: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
    apis: genPageTheme({ colors: ['#f9503c', '#fa9266'], shape: 'wave' }),
  },
  components: {
    BackstageHeader: {
      styleOverrides: {
        header: {
          background: 'radial-gradient(circle at center, #f9503c 0%, #fa9266 100%)',
          backgroundImage: 'radial-gradient(circle at center, #f9503c 0%, #fa9266 100%)',
          color: '#000000',
        },
        title: {
          color: '#000000',
        },
        subtitle: {
          color: '#000000',
        },
      },
    },
    BackstageItemCardHeader: {
      styleOverrides: {
        root: {
          background: 'radial-gradient(circle at center, #f9503c 0%, #fa9266 100%)',
          backgroundImage: 'radial-gradient(circle at center, #f9503c 0%, #fa9266 100%)',
          color: '#000000',
          '& .MuiTypography-root': {
            color: '#000000',
          },
          '& h3, & h4, & h5, & h6': {
            color: '#000000',
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          '&[data-testid="column-lifecycle"]': {
            display: 'none',
          },
          '&[data-testid="column-system"]': {
            display: 'none',
          },
          '&[data-testid="column-actions"]': {
            display: 'none',
          },
        },
        head: {
          '&:has([title="Lifecycle"])': {
            display: 'none',
          },
          '&:has([title="System"])': {
            display: 'none',
          },
          '&:has([title="Actions"])': {
            display: 'none',
          },
        },
      },
    },
  },
});

const app = createApp({
  apis,
  themes: [{
    id: 'custom-dark',
    title: 'Custom Dark',
    variant: 'dark',
    Provider: ({ children }) => (
      <UnifiedThemeProvider theme={customTheme} children={children} />
    ),
  }],
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
      viewTechDoc: techdocsPlugin.routes.docRoot,
      createFromTemplate: scaffolderPlugin.routes.selectedTemplate,
    });
    bind(apiDocsPlugin.externalRoutes, {
      registerApi: catalogImportPlugin.routes.importPage,
    });
    bind(scaffolderPlugin.externalRoutes, {
      registerComponent: catalogImportPlugin.routes.importPage,
      viewTechDoc: techdocsPlugin.routes.docRoot,
    });
    bind(orgPlugin.externalRoutes, {
      catalogIndex: catalogPlugin.routes.catalogIndex,
    });
  },
  components: {
    SignInPage: props => <SignInPage {...props} auto providers={['guest']} />,
  },
});

const routes = (
  <FlatRoutes>
    <Route path="/" element={<Navigate to="catalog" />} />
    <Route path="/catalog" element={<CatalogIndexPage />} />
    <Route
      path="/catalog/:namespace/:kind/:name"
      element={<CatalogEntityPage />}
    >
      {entityPage}
    </Route>
    <Route path="/docs" element={<TechDocsIndexPage />} />
    <Route
      path="/docs/:namespace/:kind/:name/*"
      element={<TechDocsReaderPage />}
    >
      <TechDocsAddons>
        <ReportIssue />
      </TechDocsAddons>
    </Route>
    <Route path="/create" element={<ScaffolderPage />} />
    <Route path="/api-docs" element={<ApiExplorerPage />} />
    <Route
      path="/catalog-import"
      element={
        <RequirePermission permission={catalogEntityCreatePermission}>
          <CatalogImportPage />
        </RequirePermission>
      }
    />
    <Route path="/search" element={<SearchPage />}>
      {searchPage}
    </Route>
    <Route path="/settings" element={<UserSettingsPage />} />
    <Route path="/catalog-graph" element={<CatalogGraphPage />} />
    <Route path="/notifications" element={<NotificationsPage />} />
  </FlatRoutes>
);

export default app.createRoot(
  <>
    <AlertDisplay />
    <OAuthRequestDialog />
    <SignalsDisplay />
    <AppRouter>
      <Root>{routes}</Root>
    </AppRouter>
  </>,
);
