import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CarBrand } from './car-brand.entity';
import { CarModel } from './car-model.entity';
import { CarGeneration } from './car-generation.entity';
import { PendingCarReference } from './pending-car-reference.entity';
import { ServiceCatalogItem } from './service-catalog-item.entity';
import { ServiceCatalogSuggestion } from './service-catalog-suggestion.entity';
import { ReferenceController } from './reference.controller';
import { ReferenceService } from './reference.service';
import { ServiceCatalogService } from './service-catalog.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { Organization } from '../organizations/organization.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      CarBrand,
      CarModel,
      CarGeneration,
      PendingCarReference,
      ServiceCatalogItem,
      ServiceCatalogSuggestion,
      Organization,
    ]),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [ReferenceController],
  providers: [ReferenceService, ServiceCatalogService],
  exports: [ReferenceService, ServiceCatalogService],
})
export class ReferenceModule {}
