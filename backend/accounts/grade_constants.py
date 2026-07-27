from decimal import Decimal

# Plages de montants pour chaque grade (basées sur le solde d'activation)
GRADE_PLAGE = {
    'APPRENTI': (Decimal('0'), Decimal('199999.99')),
    'COMPAGNON_N3': (Decimal('200000'), Decimal('399999.99')),
    'COMPAGNON_N2': (Decimal('400000'), Decimal('599999.99')),
    'COMPAGNON_N1': (Decimal('600000'), Decimal('799999.99')),
    'MAITRE_N3': (Decimal('800000'), Decimal('999999.99')),
    'MAITRE_N2': (Decimal('1000000'), Decimal('2099999.99')),
    'MAITRE_N1': (Decimal('2100000'), Decimal('19999999.99')),
    'GRAND_MAITRE': (Decimal('20000000'), Decimal('999999999999.99')),
}

# Pourcentages de commission par grade
COMMISSION_PERCENTAGES = {
    'APPRENTI': Decimal('2'),
    'COMPAGNON_N3': Decimal('3'),
    'COMPAGNON_N2': Decimal('4'),
    'COMPAGNON_N1': Decimal('5'),
    'MAITRE_N3': Decimal('6'),
    'MAITRE_N2': Decimal('7'),
    'MAITRE_N1': Decimal('8'),
    'GRAND_MAITRE': Decimal('0'),  # Reçoit le reste des distributions
}

# Montant minimum requis pour atteindre chaque grade (utilisé pour la montée en grade)
GRADE_MINIMUM_UPGRADE = {
    'COMPAGNON_N3': Decimal('200000'),
    'COMPAGNON_N2': Decimal('400000'),
    'COMPAGNON_N1': Decimal('600000'),
    'MAITRE_N3': Decimal('800000'),
    'MAITRE_N2': Decimal('1000000'),
    'MAITRE_N1': Decimal('2100000'),
    'GRAND_MAITRE': Decimal('20000000'),
}

# Ordre hiérarchique des grades (du plus bas au plus haut)
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

# Labels d'affichage pour les grades
GRADE_LABELS = {
    'APPRENTI': 'Apprenti',
    'COMPAGNON_N3': 'Compagnon Niveau 3',
    'COMPAGNON_N2': 'Compagnon Niveau 2',
    'COMPAGNON_N1': 'Compagnon Niveau 1',
    'MAITRE_N3': 'Maître Niveau 3',
    'MAITRE_N2': 'Maître Niveau 2',
    'MAITRE_N1': 'Maître Niveau 1',
    'GRAND_MAITRE': 'Grand Maître',
}

# Couleurs pour les badges de grade (utilisées dans le frontend)
GRADE_COLORS = {
    'APPRENTI': '#9E9E9E',      # Gris
    'COMPAGNON_N3': '#2196F3',  # Bleu
    'COMPAGNON_N2': '#4CAF50',  # Vert
    'COMPAGNON_N1': '#009688',  # Teal
    'MAITRE_N3': '#9C27B0',     # Violet
    'MAITRE_N2': '#673AB7',     # Deep Purple
    'MAITRE_N1': '#3F51B5',     # Indigo
    'GRAND_MAITRE': '#FFC107',  # Amber/Or
}


def get_grade_from_amount(amount):
    """
    Retourne le grade correspondant à un montant donné.
    
    Args:
        amount: Montant en FCFA (Decimal)
    
    Returns:
        str: Le grade correspondant
    """
    for grade, (min_montant, max_montant) in GRADE_PLAGE.items():
        if min_montant <= amount <= max_montant:
            return grade
    return 'APPRENTI'


def get_commission_percentage(grade):
    """
    Retourne le pourcentage de commission pour un grade donné.
    
    Args:
        grade: Le grade de l'utilisateur
    
    Returns:
        Decimal: Le pourcentage de commission
    """
    return COMMISSION_PERCENTAGES.get(grade, Decimal('0'))


def get_next_grade(current_grade):
    """
    Retourne le grade suivant dans la hiérarchie.
    
    Args:
        current_grade: Le grade actuel
    
    Returns:
        str or None: Le grade suivant, ou None si déjà au maximum
    """
    if current_grade not in GRADE_ORDER:
        return None
    
    current_index = GRADE_ORDER.index(current_grade)
    if current_index < len(GRADE_ORDER) - 1:
        return GRADE_ORDER[current_index + 1]
    return None


def get_minimum_for_grade(grade):
    """
    Retourne le montant minimum requis pour atteindre un grade.
    
    Args:
        grade: Le grade cible
    
    Returns:
        Decimal or None: Le montant minimum, ou None si grade invalide
    """
    return GRADE_MINIMUM_UPGRADE.get(grade)


def get_grade_display_name(grade):
    """
    Retourne le nom d'affichage d'un grade.
    
    Args:
        grade: Le grade (ex: 'COMPAGNON_N3')
    
    Returns:
        str: Le nom complet du grade (ex: 'Compagnon Niveau 3')
    """
    return GRADE_LABELS.get(grade, grade)