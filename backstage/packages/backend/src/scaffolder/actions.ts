import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import fs from 'fs-extra';
import path from 'path';

export const createPublishLocalAction = () => {
  return createTemplateAction({
    id: 'publish:local',
    description: 'Publishes the scaffolder output to a local directory',
    schema: {
      input: {
        type: 'object',
        required: ['targetPath'],
        properties: {
          targetPath: {
            type: 'string',
            title: 'Target Path',
            description: 'The path relative to the repository root where files should be copied',
          },
        },
      },
    },
    async handler(ctx) {
      const { targetPath } = ctx.input;

      // Get the workspace path (where scaffolder created the files)
      const workspacePath = ctx.workspacePath;

      // Resolve the absolute target path (repository root)
      const repoRoot = path.resolve(__dirname, '../../../../..');
      const absoluteTargetPath = path.resolve(repoRoot, targetPath);

      ctx.logger.info(`Copying files from ${workspacePath} to ${absoluteTargetPath}`);

      // Ensure target directory exists
      await fs.ensureDir(path.dirname(absoluteTargetPath));

      // Copy all files from workspace to target
      await fs.copy(workspacePath, absoluteTargetPath, {
        overwrite: true,
        recursive: true,
      });

      ctx.logger.info(`Successfully published to ${absoluteTargetPath}`);

      ctx.output('targetPath', absoluteTargetPath);
    },
  });
};
