export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "12.2.12 (cd3cf9e)"
  }
  public: {
    Tables: {
      business_users: {
        Row: {
          address: string | null
          bankAccountName: string | null
          contactEmail: string | null
          contactName: string | null
          created_at: string | null
          fullName: string | null
          iban: string | null
          id: number
          publicName: string | null
          userId: number | null
        }
        Insert: {
          address?: string | null
          bankAccountName?: string | null
          contactEmail?: string | null
          contactName?: string | null
          created_at?: string | null
          fullName?: string | null
          iban?: string | null
          id?: number
          publicName?: string | null
          userId?: number | null
        }
        Update: {
          address?: string | null
          bankAccountName?: string | null
          contactEmail?: string | null
          contactName?: string | null
          created_at?: string | null
          fullName?: string | null
          iban?: string | null
          id?: number
          publicName?: string | null
          userId?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "business_users_userId_fkey"
            columns: ["userId"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      digital_invoices: {
        Row: {
          amount: number | null
          category: string | null
          created_at: string | null
          data: Json | null
          deadline: string | null
          description: string | null
          id: number
          invoiceNo: string | null
          isObsolete: boolean | null
          isSeen: boolean | null
          lastRemindedAt: string | null
          originalInvoiceNo: string | null
          paidOnDate: string | null
          privateGroupId: number | null
          rawInvoiceId: number | null
          receiverId: number | null
          receiverPrivateUserId: number | null
          referenceNo: string | null
          senderIban: string | null
          senderId: number | null
          senderIsBusiness: boolean
          senderName: string | null
          senderPrivateUserId: number | null
          status: string
          txHash: string | null
          updated_at: string | null
        }
        Insert: {
          amount?: number | null
          category?: string | null
          created_at?: string | null
          data?: Json | null
          deadline?: string | null
          description?: string | null
          id?: number
          invoiceNo?: string | null
          isObsolete?: boolean | null
          isSeen?: boolean | null
          lastRemindedAt?: string | null
          originalInvoiceNo?: string | null
          paidOnDate?: string | null
          privateGroupId?: number | null
          rawInvoiceId?: number | null
          receiverId?: number | null
          receiverPrivateUserId?: number | null
          referenceNo?: string | null
          senderIban?: string | null
          senderId?: number | null
          senderIsBusiness?: boolean
          senderName?: string | null
          senderPrivateUserId?: number | null
          status?: string
          txHash?: string | null
          updated_at?: string | null
        }
        Update: {
          amount?: number | null
          category?: string | null
          created_at?: string | null
          data?: Json | null
          deadline?: string | null
          description?: string | null
          id?: number
          invoiceNo?: string | null
          isObsolete?: boolean | null
          isSeen?: boolean | null
          lastRemindedAt?: string | null
          originalInvoiceNo?: string | null
          paidOnDate?: string | null
          privateGroupId?: number | null
          rawInvoiceId?: number | null
          receiverId?: number | null
          receiverPrivateUserId?: number | null
          referenceNo?: string | null
          senderIban?: string | null
          senderId?: number | null
          senderIsBusiness?: boolean
          senderName?: string | null
          senderPrivateUserId?: number | null
          status?: string
          txHash?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "digital_invoices_privateGroupId_fkey"
            columns: ["privateGroupId"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "digital_invoices_rawInvoiceId_fkey"
            columns: ["rawInvoiceId"]
            isOneToOne: false
            referencedRelation: "raw_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "digital_invoices_receiverId_fkey"
            columns: ["receiverId"]
            isOneToOne: false
            referencedRelation: "receivers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "digital_invoices_receiverPrivateUserId_fkey"
            columns: ["receiverPrivateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "digital_invoices_senderId_fkey"
            columns: ["senderId"]
            isOneToOne: false
            referencedRelation: "senders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "digital_invoices_senderPrivateUserId_fkey"
            columns: ["senderPrivateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          created_at: string
          digitalInvoiceId: number | null
          id: number
        }
        Insert: {
          created_at?: string
          digitalInvoiceId?: number | null
          id?: number
        }
        Update: {
          created_at?: string
          digitalInvoiceId?: number | null
          id?: number
        }
        Relationships: [
          {
            foreignKeyName: "payments_digitalInvoiceId_fkey"
            columns: ["digitalInvoiceId"]
            isOneToOne: false
            referencedRelation: "digital_invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      private_groups: {
        Row: {
          created_at: string | null
          creatorUserId: number | null
          deadline: string | null
          description: string | null
          id: number
        }
        Insert: {
          created_at?: string | null
          creatorUserId?: number | null
          deadline?: string | null
          description?: string | null
          id?: number
        }
        Update: {
          created_at?: string | null
          creatorUserId?: number | null
          deadline?: string | null
          description?: string | null
          id?: number
        }
        Relationships: [
          {
            foreignKeyName: "private_groups_creatorUserId_fkey"
            columns: ["creatorUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      private_groups_users: {
        Row: {
          created_at: string | null
          id: number
          orivateGroupId: number | null
          privateUserId: number | null
        }
        Insert: {
          created_at?: string | null
          id?: number
          orivateGroupId?: number | null
          privateUserId?: number | null
        }
        Update: {
          created_at?: string | null
          id?: number
          orivateGroupId?: number | null
          privateUserId?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "private_groups_users_orivateGroupId_fkey"
            columns: ["orivateGroupId"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "private_groups_users_privateUserId_fkey"
            columns: ["privateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      private_users: {
        Row: {
          bankAccountName: string | null
          created_at: string | null
          firstName: string | null
          iban: string | null
          ibans: Json | null
          id: number
          isBusiness: boolean
          lastName: string | null
          publicName: string | null
          userId: number | null
        }
        Insert: {
          bankAccountName?: string | null
          created_at?: string | null
          firstName?: string | null
          iban?: string | null
          ibans?: Json | null
          id?: number
          isBusiness?: boolean
          lastName?: string | null
          publicName?: string | null
          userId?: number | null
        }
        Update: {
          bankAccountName?: string | null
          created_at?: string | null
          firstName?: string | null
          iban?: string | null
          ibans?: Json | null
          id?: number
          isBusiness?: boolean
          lastName?: string | null
          publicName?: string | null
          userId?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "private_users_userId_fkey"
            columns: ["userId"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      public_digital_invoices: {
        Row: {
          amount: number | null
          category: string | null
          claimCount: number | null
          created_at: string | null
          data: Json | null
          deadline: string | null
          description: string | null
          externalPaymentCount: number | null
          id: number
          invoiceNo: string | null
          isObsolete: boolean | null
          isSeen: boolean | null
          originalInvoiceNo: string | null
          paidOnDate: string | null
          privateGroupId: number | null
          publicToken: string
          rawInvoiceId: number | null
          receiverPrivateUserId: number | null
          referenceNo: string | null
          senderIban: string | null
          senderIsBusiness: boolean
          senderName: string | null
          senderPrivateUserId: number | null
          status: string
          updated_at: string | null
          viewCount: number | null
        }
        Insert: {
          amount?: number | null
          category?: string | null
          claimCount?: number | null
          created_at?: string | null
          data?: Json | null
          deadline?: string | null
          description?: string | null
          externalPaymentCount?: number | null
          id?: number
          invoiceNo?: string | null
          isObsolete?: boolean | null
          isSeen?: boolean | null
          originalInvoiceNo?: string | null
          paidOnDate?: string | null
          privateGroupId?: number | null
          publicToken?: string
          rawInvoiceId?: number | null
          receiverPrivateUserId?: number | null
          referenceNo?: string | null
          senderIban?: string | null
          senderIsBusiness?: boolean
          senderName?: string | null
          senderPrivateUserId?: number | null
          status?: string
          updated_at?: string | null
          viewCount?: number | null
        }
        Update: {
          amount?: number | null
          category?: string | null
          claimCount?: number | null
          created_at?: string | null
          data?: Json | null
          deadline?: string | null
          description?: string | null
          externalPaymentCount?: number | null
          id?: number
          invoiceNo?: string | null
          isObsolete?: boolean | null
          isSeen?: boolean | null
          originalInvoiceNo?: string | null
          paidOnDate?: string | null
          privateGroupId?: number | null
          publicToken?: string
          rawInvoiceId?: number | null
          receiverPrivateUserId?: number | null
          referenceNo?: string | null
          senderIban?: string | null
          senderIsBusiness?: boolean
          senderName?: string | null
          senderPrivateUserId?: number | null
          status?: string
          updated_at?: string | null
          viewCount?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "public_digital_invoices_privateGroupId_fkey"
            columns: ["privateGroupId"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_digital_invoices_rawInvoiceId_fkey"
            columns: ["rawInvoiceId"]
            isOneToOne: false
            referencedRelation: "raw_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_digital_invoices_receiverPrivateUserId_fkey"
            columns: ["receiverPrivateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_digital_invoices_senderPrivateUserId_fkey"
            columns: ["senderPrivateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      public_invoice_claims: {
        Row: {
          claimed_by_user_id: number | null
          created_at: string
          digital_invoice_id: number | null
          id: number
          public_invoice_id: number | null
        }
        Insert: {
          claimed_by_user_id?: number | null
          created_at?: string
          digital_invoice_id?: number | null
          id?: number
          public_invoice_id?: number | null
        }
        Update: {
          claimed_by_user_id?: number | null
          created_at?: string
          digital_invoice_id?: number | null
          id?: number
          public_invoice_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "public_invoice_claims_claimed_by_user_id_fkey"
            columns: ["claimed_by_user_id"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_invoice_claims_digital_invoice_id_fkey"
            columns: ["digital_invoice_id"]
            isOneToOne: false
            referencedRelation: "digital_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_invoice_claims_public_invoice_id_fkey"
            columns: ["public_invoice_id"]
            isOneToOne: false
            referencedRelation: "public_digital_invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      raw_invoices: {
        Row: {
          created_at: string | null
          fileUrl: string | null
          id: number
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          fileUrl?: string | null
          id?: number
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          fileUrl?: string | null
          id?: number
          updated_at?: string | null
        }
        Relationships: []
      }
      receivers: {
        Row: {
          businessUserId: number | null
          created_at: string | null
          id: number
          privateUserId: number | null
        }
        Insert: {
          businessUserId?: number | null
          created_at?: string | null
          id?: number
          privateUserId?: number | null
        }
        Update: {
          businessUserId?: number | null
          created_at?: string | null
          id?: number
          privateUserId?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "receivers_businessUserId_fkey"
            columns: ["businessUserId"]
            isOneToOne: false
            referencedRelation: "business_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receivers_privateUserId_fkey"
            columns: ["privateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      senders: {
        Row: {
          businessUserId: number | null
          created_at: string | null
          id: number
          privateUserId: number | null
        }
        Insert: {
          businessUserId?: number | null
          created_at?: string | null
          id?: number
          privateUserId?: number | null
        }
        Update: {
          businessUserId?: number | null
          created_at?: string | null
          id?: number
          privateUserId?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "senders_businessUserId_fkey"
            columns: ["businessUserId"]
            isOneToOne: false
            referencedRelation: "business_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "senders_privateUserId_fkey"
            columns: ["privateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      tickets: {
        Row: {
          category: string | null
          created_at: string | null
          dateOfActivity: string | null
          description: string | null
          id: number
          privateUserId: number | null
          qrCodeLink: string | null
          title: string | null
        }
        Insert: {
          category?: string | null
          created_at?: string | null
          dateOfActivity?: string | null
          description?: string | null
          id?: number
          privateUserId?: number | null
          qrCodeLink?: string | null
          title?: string | null
        }
        Update: {
          category?: string | null
          created_at?: string | null
          dateOfActivity?: string | null
          description?: string | null
          id?: number
          privateUserId?: number | null
          qrCodeLink?: string | null
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tickets_privateUserId_fkey"
            columns: ["privateUserId"]
            isOneToOne: false
            referencedRelation: "private_users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_devices: {
        Row: {
          created_at: string
          device_type: string | null
          id: number
          last_active: string | null
          player_id: string
          user_id: number | null
        }
        Insert: {
          created_at?: string
          device_type?: string | null
          id?: number
          last_active?: string | null
          player_id: string
          user_id?: number | null
        }
        Update: {
          created_at?: string
          device_type?: string | null
          id?: number
          last_active?: string | null
          player_id?: string
          user_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "user_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          authUserId: string | null
          cdpUserId: string | null
          cdpWalletId: string | null
          created_at: string | null
          email: string | null
          fcm_token: string | null
          id: number
          phoneCountryCode: string
          phoneNumber: number
          strigaUserId: string | null
          strigaWalletId: string | null
          username: string
        }
        Insert: {
          authUserId?: string | null
          cdpUserId?: string | null
          cdpWalletId?: string | null
          created_at?: string | null
          email?: string | null
          fcm_token?: string | null
          id?: number
          phoneCountryCode?: string
          phoneNumber?: number
          strigaUserId?: string | null
          strigaWalletId?: string | null
          username: string
        }
        Update: {
          authUserId?: string | null
          cdpUserId?: string | null
          cdpWalletId?: string | null
          created_at?: string | null
          email?: string | null
          fcm_token?: string | null
          id?: number
          phoneCountryCode?: string
          phoneNumber?: number
          strigaUserId?: string | null
          strigaWalletId?: string | null
          username?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
