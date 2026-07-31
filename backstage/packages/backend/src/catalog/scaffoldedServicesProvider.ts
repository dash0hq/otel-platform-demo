import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import { catalogProcessingExtensionPoint } from '@backstage/plugin-catalog-node';
import type {
  EntityProvider,
  EntityProviderConnection,
} from '@backstage/plugin-catalog-node';
import fs from 'fs-extra';
import path from 'path';

/**
 * Discovers services by scanning `services/<name>/catalog-info.yaml` in the repo.
 *
 * The demo scaffolds a service into that directory at runtime, and without this the
 * only ways to get it into the catalog are to hand-edit `catalog.locations` and
 * restart, or to register it in Backstage's database -- which is in-memory here, so
 * it would not survive a restart either. Scanning covers both directions: a
 * scaffolded service appears on its own, and `02_cleanup.sh` removing the directory
 * makes it disappear.
 *
 * Each discovered file is emitted as a `Location` entity rather than as the parsed
 * component, so Backstage's own file-location processor does the reading. That keeps
 * multi-document catalog-info files (todo-service and notification-service both
 * declare a Component plus APIs) working without any parsing here.
 */
class ScaffoldedServicesProvider implements EntityProvider {
  private connection?: EntityProviderConnection;

  constructor(private readonly servicesDir: string) {}

  getProviderName(): string {
    return 'scaffolded-services';
  }

  async connect(connection: EntityProviderConnection): Promise<void> {
    this.connection = connection;
  }

  async refresh(): Promise<void> {
    if (!this.connection) {
      return;
    }

    const targets: string[] = [];
    if (await fs.pathExists(this.servicesDir)) {
      for (const entry of await fs.readdir(this.servicesDir, {
        withFileTypes: true,
      })) {
        if (!entry.isDirectory()) {
          continue;
        }
        const target = path.join(
          this.servicesDir,
          entry.name,
          'catalog-info.yaml',
        );
        if (await fs.pathExists(target)) {
          targets.push(target);
        }
      }
    }

    // A full mutation, so a service whose directory has been deleted is removed
    // from the catalog rather than lingering as an orphan.
    await this.connection.applyMutation({
      type: 'full',
      entities: targets.map(target => {
        const location = `file:${target}`;
        return {
          locationKey: this.getProviderName(),
          entity: {
            apiVersion: 'backstage.io/v1alpha1',
            kind: 'Location',
            metadata: {
              name: `services-${path.basename(path.dirname(target))}`,
              annotations: {
                'backstage.io/managed-by-location': location,
                'backstage.io/managed-by-origin-location': location,
              },
            },
            spec: {
              type: 'file',
              target,
              // Tolerate the file vanishing between the scan and the read, which
              // happens when the cleanup script runs while a refresh is in flight.
              presence: 'optional',
            },
          },
        };
      }),
    });
  }
}

export const catalogModuleScaffoldedServices = createBackendModule({
  pluginId: 'catalog',
  moduleId: 'scaffolded-services',
  register(env) {
    env.registerInit({
      deps: {
        catalog: catalogProcessingExtensionPoint,
        scheduler: coreServices.scheduler,
        rootConfig: coreServices.rootConfig,
      },
      async init({ catalog, scheduler }) {
        // packages/backend/src -> repo root
        const repoRoot = path.resolve(__dirname, '../../../../..');
        const provider = new ScaffoldedServicesProvider(
          path.join(repoRoot, 'services'),
        );
        catalog.addEntityProvider(provider);

        await scheduler.scheduleTask({
          id: 'scaffolded-services-refresh',
          // Short on purpose: this is the gap between clicking Create in the
          // scaffolder and the component showing up in the catalog.
          frequency: { seconds: 10 },
          timeout: { seconds: 30 },
          fn: async () => {
            await provider.refresh();
          },
        });
      },
    });
  },
});
