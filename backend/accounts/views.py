from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from .models import User
from .serializers import UserSerializer, UserRegistrationSerializer, UserLoginSerializer
from django.db.models import Sum
from decimal import Decimal
from transactions.models import Transaction  # Import explicite

class RegisterView(generics.CreateAPIView):
    """Inscription d'un nouvel utilisateur."""
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """Connexion utilisateur."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = UserLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        email = serializer.validated_data['email']
        password = serializer.validated_data['password']
        
        user = authenticate(email=email, password=password)
        
        if not user:
            return Response(
                {'detail': 'Email ou mot de passe incorrect'},
                status=status.HTTP_401_UNAUTHORIZED
            )
            
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        })


class ProfileView(generics.RetrieveAPIView):
    """Profil de l'utilisateur connecté."""
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        user = self.request.user
        # Rafraîchir depuis la base de données
        user.refresh_from_db()
        return user


class SponsoredUsersView(APIView):
    """Lister les filleuls directs de l'utilisateur connecté."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        user.refresh_from_db()
        
        # Récupérer tous les filleuls directs
        sponsored_users = User.objects.filter(sponsor=user)
        
        # Statistiques
        total_sponsored = sponsored_users.count()
        
        filleuls_data = []
        for filleul in sponsored_users:
            # Total des dépôts de ce filleul
            total_depots = Transaction.objects.filter(
                utilisateur=filleul,
                type_transaction='DEPOT',
                statut='VALIDEE'
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            
            # Commissions générées par ce filleul (niveau 1)
            commissions_generees = Transaction.objects.filter(
                transaction_originale__utilisateur=filleul,
                type_transaction='COMMISSION',
                niveau_commission=1,
                utilisateur=user
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            
            filleuls_data.append({
                'id': filleul.id,
                'email': filleul.email,
                'full_name': filleul.full_name,
                'phone_number': filleul.phone_number,
                'grade': filleul.grade,
                'referral_code': filleul.referral_code,
                'date_joined': filleul.date_joined,
                'total_depots': float(total_depots),
                'commissions_generees': float(commissions_generees),
            })
        
        return Response({
            'total_sponsored': total_sponsored,
            'filleuls': filleuls_data,
        })