import { BookingService, AvailableSlotsDto } from './booking.service';
export declare class BookingController {
    private booking;
    constructor(booking: BookingService);
    getAvailableSlots(body: AvailableSlotsDto): Promise<{
        slots: import("./booking.service").TimeSlot[];
        total_minutes: number;
        required_skills: string[];
        slot_duration_minutes: number;
        work_day_start: string;
        work_day_end: string;
        scheduling_mode: string;
        bay_count?: number;
    }>;
    clearTestOrders(): Promise<{
        deletedOrders: number;
        deletedItems: number;
    }>;
}
