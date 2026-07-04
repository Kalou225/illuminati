from decimal import Decimal

# Définition des tranches de grades
GRADE_TRANCHES = {
    'APPRENTI': {
        'min': Decimal('1'),
        'max': Decimal('200000'),
        'commission_percentage': Decimal('2'),
    },
    'COMPAGNON_N3': {
        'min': Decimal('201000'),
        'max': Decimal('400000'),
        'commission_percentage': Decimal('3'),
    },
    'COMPAGNON_N2': {
        'min': Decimal('401000'),
        'max': Decimal('600000'),
        'commission_percentage': Decimal('4'),
    },
    'COMPAGNON_N1': {
        'min': Decimal('601000'),
        'max': Decimal('800000'),
        'commission_percentage': Decimal('5'),
    },
    'MAITRE_N3': {
        'min': Decimal('801000'),
        'max': Decimal('1000000'),
        'commission_percentage': Decimal('6'),
    },
    'MAITRE_N2': {
        'min': Decimal('1001000'),
        'max': Decimal('2000000'),
        'commission_percentage': Decimal('7'),
    },
    'MAITRE_N1': {
        'min': Decimal('2100000'),
        'max': Decimal('19999999'),
        'commission_percentage': Decimal('8'),
    },
    'GRAND_MAITRE': {
        'min': Decimal('20000000'),
        'max': None,  # Pas de limite supérieure
        'commission_percentage': Decimal('0'),
    },
}

GRADE_ORDER = [
    'APPRENTI',
    'COMPAGNON_N3',
    'COMPAGNON_N2',
    'COMPAGNON_N1',
    'MAITRE_N3',
    'MAITRE_N2',
    'MAITRE_N1',
    'GRAND_MAITRE',
]


def get_grade_from_amount(amount):
    """Retourne le grade correspondant à un montant donné."""
    for grade_name, tranches in GRADE_TRANCHES.items():
        min_amount = tranches['min']
        max_amount = tranches['max']
        
        if amount >= min_amount:
            if max_amount is None or amount <= max_amount:
                return grade_name
    
    return 'APPRENTI'


def get_next_grade(current_grade):
    """Retourne le grade suivant."""
    try:
        current_index = GRADE_ORDER.index(current_grade)
        if current_index + 1 < len(GRADE_ORDER):
            return GRADE_ORDER[current_index + 1]
    except ValueError:
        pass
    return None


def get_grade_display_name(grade):
    """Retourne le nom affiché du grade."""
    display_names = {
        'APPRENTI': 'Apprenti',
        'COMPAGNON_N3': 'Compagnon Niveau 3',
        'COMPAGNON_N2': 'Compagnon Niveau 2',
        'COMPAGNON_N1': 'Compagnon Niveau 1',
        'MAITRE_N3': 'Maître Niveau 3',
        'MAITRE_N2': 'Maître Niveau 2',
        'MAITRE_N1': 'Maître Niveau 1',
        'GRAND_MAITRE': 'Grand Maître',
    }
    return display_names.get(grade, grade)