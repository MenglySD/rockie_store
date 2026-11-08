import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/provider/home_provider.dart';
import 'package:rockie_store/repositories/address_repository.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/repositories/cart_repository.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/repositories/payment_method_repository.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/repositories/profile_repository.dart';
import 'package:rockie_store/services/api_client.dart';
import 'package:rockie_store/services/token_storage.dart';

/// Used to send the user to the login screen from outside the widget tree (401).
final navigatorKey = GlobalKey<NavigatorState>();

final apiClient = ApiClient(tokens: TokenStorage());

final List<SingleChildWidget> providers = [
  // Repositories: widgets read these, never Dio.
  Provider(create: (_) => AuthRepository(apiClient)),
  Provider(create: (_) => ProfileRepository(apiClient)),
  Provider(create: (_) => ProductRepository(apiClient)),
  Provider(create: (_) => CartRepository(apiClient)),
  Provider(create: (_) => AddressRepository(apiClient)),
  Provider(create: (_) => PaymentMethodRepository(apiClient)),
  Provider(create: (_) => OrderRepository(apiClient)),

  // App state.
  ChangeNotifierProvider(create: (_) => HomeProvider()),
  ChangeNotifierProvider(
    create: (context) => AuthProvider(
      context.read<AuthRepository>(),
      context.read<ProfileRepository>(),
    ),
  ),
  ChangeNotifierProvider(create: (context) => CartProvider(context.read<CartRepository>())),
];
