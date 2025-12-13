import { Router } from 'express';
import { listen } from '../controllers/voiceController';

const router = Router();

router.get('/listen', listen);

export default router;

